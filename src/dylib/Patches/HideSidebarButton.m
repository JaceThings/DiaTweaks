#import "../DiaPatches.h"

static NSColor *DPOrange(void) { return NSColor.systemOrangeColor; }

DPPatch DPHideSidebarButton = {
    .key = @"hideSidebarButton",
    .title = @"Hide sidebar button",
    .detail = @"Hide the sidebar toggle at the top left of the toolbar.",
    .symbol = @"sidebar.left",
    .tint = DPOrange,
    .disabledBy = &DPHideToolbar,
    .apply = DPApplyButtons,
};
