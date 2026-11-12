#import "CompactSidebar.h"
#import "Patches/HideToolbar/HideToolbar.h"

// On, ⌘S hides the toolbar along with the strip, through Hide Toolbar without saving it, and gives it back with the strip.
// It only turns off what it turned on: Hide Toolbar's own switch, or anything else that turned it on, keeps it.
static BOOL DPStripHidToolbar;

void DPMatchStripToolbar(BOOL stripHidden) {
    if (DPHideToolbar.unavailable) return;
    BOOL hide = stripHidden && DPCompactSidebarHidesToolbar.on && DPCompactSidebar.on;
    if (hide && !DPHideToolbar.on) {
        DPStripHidToolbar = YES;
        DPSetPatch(&DPHideToolbar, YES, NO);
    } else if (!hide && DPStripHidToolbar) {
        DPStripHidToolbar = NO;
        if (!DPHideToolbar.on || DPSavedOn(&DPHideToolbar)) return;
        DPSetPatch(&DPHideToolbar, NO, NO);
    } else return;
    [NSNotificationCenter.defaultCenter postNotificationName:DPPatchesDidChangeNotification object:nil];
}

static void DPApplyCompactSidebarHidesToolbar(DPPatch *patch) { DPMatchStripToolbar(NO); }

DP_PATCH(DPCompactSidebarHidesToolbar) {
    .key = @"compactSidebarHidesToolbar",
    .order = 79,
    .title = @"Hide Toolbar with ⌘S",
    .detail = @"⌘S hides the toolbar along with the strip, and brings both back.",
    .symbol = @"menubar.arrow.up.rectangle",
    .tint = @"systemTealColor",
    .requires = @"compactSidebar",
    .apply = DPApplyCompactSidebarHidesToolbar,
};
