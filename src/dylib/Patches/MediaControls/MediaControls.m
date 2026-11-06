#import "Views.h"

// A change in a window's tabs updates its stack, then every sidebar showing it: the window's own and a floating one.
static void DPMediaChanged(NSWindow *window) {
    DPMediaStack *stack = DPMediaStackOf(window);
    [stack updateWithItems:DPMediaItemsInWindow(window) selectedTab:DPSelectedTab(window)];
    for (NSView *sidebar in DPMediaSidebars().allObjects) {
        if (sidebar.window != window) continue;
        DPPlaceMediaStack(sidebar);  // Dia may not have laid the sidebar out since it joined the window.
        [DPMediaStackViewIn(sidebar) reload];
    }
}

static void DPInstallMediaControls(void) {
    DPInstallMediaTabs();
    DPInstallMediaPiP();
    DPInstallMediaSource(^(NSWindow *window) { DPMediaChanged(window); });
    DPInstallMediaLayout();
}

static void DPApplyMediaControls(DPPatch *patch) {
    for (NSView *sidebar in DPMediaSidebars().allObjects) {
        if (patch->on && sidebar.window) DPMediaChanged(sidebar.window);
        DPPlaceMediaStack(sidebar);
    }
}

// While on, a sidebar whose window has a background media tab shows the stack above its footer; while off, none does.
static NSString *DPVerifyMediaControls(DPPatch *patch) {
    for (NSView *footer in DPFindViews(DPDiaSidebarFooter)) {
        NSView *sidebar = footer.superview;
        if (!sidebar.window || sidebar.hiddenOrHasHiddenAncestor) continue;
        DPMediaStackView *view = (DPMediaStackView *)DPSubview(sidebar, "DPMediaStackView");
        if (!patch->on && view) return @"media controls still showing";
        if (!patch->on || ![DPTabLayout() isEqual:@"vertical"]) continue;
        BOOL media = DPMediaStackOf(sidebar.window).visible.count > 0;
        if (media && (!view || view.hidden)) return @"media controls missing";
        if (media && NSMaxY(view.frame) > NSMinY(footer.frame) + 0.5) return @"media controls overlap the footer";
    }
    return nil;
}

DP_PATCH(DPMediaControls) {
    .key = @"mediaControls",
    .order = 81,
    .section = @"Sidebar & Tab Bar",
    .title = @"Media Controls",
    .detail = @"Shows what's playing in other tabs at the bottom of the sidebar, with play, pause, skip and mute.",
    .symbol = @"play.rectangle.on.rectangle play.rectangle",
    .tint = @"systemPinkColor",
    .classes = DPClasses(DPDiaSidebarController, DPDiaSidebarFooter, DPDiaWebContent, DPDiaWebContents, DPDiaBrowser, DPDiaBrowserDelegate),
    .install = DPInstallMediaControls,
    .apply = DPApplyMediaControls,
    .verify = DPVerifyMediaControls,
};

static void DPApplyMediaAfterPiP(DPPatch *patch) { DPApplyMediaControls(&DPMediaControls); }

// While on, no card shows a tab whose picture in picture window is open.
static NSString *DPVerifyMediaAfterPiP(DPPatch *patch) {
    for (DPMediaCard *card in DPFindViews("DPMediaCard"))
        if (DPMediaWaitsForPiP(card.item.tab)) return @"a card shows while its picture in picture is open";
    return nil;
}

DP_PATCH(DPMediaAfterPiP) {
    .key = @"mediaControlsAfterPiP",
    .order = 81,
    .title = @"Wait for Picture in Picture",
    .detail = @"When a video goes into picture in picture as you leave its tab, show its controls only once you close that window.",
    .symbol = @"pip pip.fill play.rectangle",
    .tint = @"systemPinkColor",
    .requires = @"mediaControls",
    .classes = DPClasses(DPDiaWebContent),
    .apply = DPApplyMediaAfterPiP,
    .verify = DPVerifyMediaAfterPiP,
};
