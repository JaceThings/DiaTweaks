#import "Patches/SwipeNewProfile/SwipeNewProfile.h"
#import "Patches/CommandBar/Tabs.h"

// The sidebar a swipe is over, or nil with tabs at the top or the sidebar hidden.
// Walks up from what's under the pointer, so a scroll elsewhere costs little.
static NSView *DPSidebarUnder(NSEvent *event) {
    NSView *frame = event.window.contentView.superview;
    for (NSView *view = [frame hitTest:event.locationInWindow]; view; view = view.superview)
        if (DPSubview(view, DPDiaSidebarFooter)) return view.hiddenOrHasHiddenAncestor ? nil : view;
    return nil;
}

// How many profiles after the window's current one, or -1 if it can't tell.
static NSInteger DPProfilesAfter(NSWindow *window) {
    id scriptWindow = DPScriptWindow(window);
    id profiles = DPValueForKey(scriptWindow, @"appleScriptProfiles");
    id index = DPValueForKey(DPValueForKey(scriptWindow, @"activeProfile"), @"orderedIndex");
    if (![profiles isKindOfClass:NSArray.class] || ![index respondsToSelector:@selector(integerValue)] || [index integerValue] < 1) return -1;
    return (NSInteger)[profiles count] - [index integerValue];
}

static void DPInstallSwipeNewProfile(void) {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel handler:^NSEvent *(NSEvent *event) {
        BOOL handled;
        NSEvent *out = DPPullEvent(event, &handled);
        if (handled) return out;
        if (!DPSwipeNewProfile.on || event.phase != NSEventPhaseBegan || !event.hasPreciseScrollingDeltas) return event;
        NSView *sidebar = DPSidebarUnder(event);
        NSInteger after = sidebar ? DPProfilesAfter(event.window) : -1;
        if (after == 0 && DPHasNewProfileItem()) DPStartPull(event, sidebar);
        return event;
    }];
}

static void DPApplySwipeNewProfile(DPPatch *patch) {
    if (!patch->on) DPEndPull(NO);
}

static NSString *DPVerifySwipeNewProfile(DPPatch *patch) {
    if (patch->on && !DPHasNewProfileItem()) return @"Dia has no New Profile… menu item";
    for (NSView *footer in DPFindViews(DPDiaSidebarFooter))
        for (NSView *view in footer.superview.subviews)
            if (DPIsPullIndicator(view)) return @"a + is left in the sidebar";
    return nil;
}

DP_PATCH(DPSwipeNewProfile) {
    .key = @"swipeNewProfile",
    .order = 82,
    .title = @"Swipe for a New Profile",
    .detail = @"Keep swiping past your last profile in the sidebar, like Arc’s spaces. A + fills as you pull; let go once it’s full to open New Profile, or swipe back to cancel. Experimental.",
    .symbol = @"plus.circle",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSidebarFooter),
    .install = DPInstallSwipeNewProfile,
    .apply = DPApplySwipeNewProfile,
    .verify = DPVerifySwipeNewProfile,
};
