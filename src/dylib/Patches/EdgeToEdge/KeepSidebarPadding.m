#import "EdgeToEdge.h"

// Square corners next to the sidebar need the page edge-to-edge there, so they win over the padding.
BOOL DPKeepsSidebarPadding(void) {
    return DPKeepSidebarPadding.on && !DPSquareSidebarCorners.on;
}

static NSString *DPVerifyKeepSidebarPadding(DPPatch *patch) {
    if (!DPEdgeToEdge.on) return nil;
    for (NSView *container in DPFindViews(DPDiaContentContainer)) {
        NSValue *requested = DPRequestedFrame(container);
        if (!requested || !DPBesideSidebar(container)) continue;
        BOOL kept = NSEqualRects(container.frame, requested.rectValue);
        if (kept != DPSteppedAside(container)) return kept ? @"padding is left out beside the sidebar" : @"padding is lost beside the sidebar";
    }
    return nil;
}

DP_PATCH(DPKeepSidebarPadding) {
    .key = @"keepPaddingNextToSidebar",
    .order = 25,
    .title = @"Keep Padding Next to Sidebar",
    .detail = @"Keep the window's padding around web pages beside the sidebar instead of running them to its edge. Square Corners Next to Sidebar takes priority.",
    .symbol = @"sidebar.left",
    .tint = @"systemBlueColor",
    .requires = @"edgeToEdge",
    .disabledBy = @"squareSidebarCorners",
    .verify = DPVerifyKeepSidebarPadding,
};
