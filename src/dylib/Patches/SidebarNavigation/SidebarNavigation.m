#import "SidebarNavigation.h"

static void DPInstallSidebarNavigation(void) {
    DPOnLaunch(^{
        DPInstallSidebarNavigationLifecycle();
        DPInstallSidebarNavigationLayout();
    });
}

static NSString *DPVerifySidebarNavigation(DPPatch *patch) {
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        if (header.hiddenOrHasHiddenAncestor) continue;
        BOOL active = DPSidebarNavigationControls.on && DPSubview(header.superview, DPDiaSidebarFooter);
        DPSidebarNavigationState *state = DPNavigationState(header, NO);
        for (DPNavigationSlot *slot in state.toolbarControls.allValues)
            if ((!active || !DPSidebarNavigation.on) && slot.view) return @"navigation remains moved while off";
        if ((!active || !DPSidebarHideProfile.on) && state.hiddenProfile) return @"profile remains hidden while off";
        if (active && DPSidebarNavigation.on && DPSidebarHideProfile.on && state.toolbar && NSWidth(header.bounds) >= 220) {
            DPNavigationSlot *back = state.toolbarControls[@"Go back"];
            if (!back.view || back.view.superview != header) return @"sidebar Back button is missing";
        }
    }
    for (NSView *strip in DPFindViews(DPDiaTabStrip)) {
        DPSidebarNavigationState *state = DPNavigationState(strip, NO);
        BOOL active = DPHorizontalNavigationAvailable(strip) && DPSidebarNavigation.on;
        if (!active && (state.toolbarControls.count || state.shiftedViews.count)) return @"top navigation remains moved while off";
        if (active && state.toolbar && NSWidth(strip.bounds) >= 350) {
            DPNavigationSlot *back = state.toolbarControls[@"Go back"];
            if (!back.view || back.view.superview != strip) return @"top Back button is missing";
        }
    }
    return nil;
}

DP_PATCH(DPSidebarNavigationControls) {
    .key = @"sidebarNavigationControls", .order = 86,
    .title = @"Sidebar navigation",
    .detail = @"Place navigation beside the window controls in either tab layout.",
    .symbol = @"arrow.left.arrow.right", .tint = @"systemTealColor", .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSidebarHeader, DPDiaToolbar),
    .install = DPInstallSidebarNavigation, .apply = DPApplySidebarNavigation,
    .verify = DPVerifySidebarNavigation,
};
DP_PATCH(DPSidebarNavigation) {
    .key = @"sidebarNavigation", .defaultOn = YES, .order = 95,
    .title = @"Move navigation buttons",
    .detail = @"Place Back, Forward and Reload beside the window controls.",
    .symbol = @"arrow.left.arrow.right", .section = @"Sidebar & Tab Bar",
    .requires = @"sidebarNavigationControls", .apply = DPApplySidebarNavigation,
};
DP_PATCH(DPSidebarHideProfile) {
    .key = @"sidebarHideProfile", .defaultOn = YES, .order = 97,
    .title = @"Hide sidebar profile switcher",
    .detail = @"Hide the profile button. Switch profiles from Dia’s menu.",
    .symbol = @"person.crop.circle", .section = @"Sidebar & Tab Bar",
    .requires = @"sidebarNavigationControls", .apply = DPApplySidebarNavigation,
};
