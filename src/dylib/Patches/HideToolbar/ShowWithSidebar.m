#import "HideToolbar.h"

static void DPApplyShowWithSidebar(DPPatch *patch) { DPRelayoutPanes(); }

static NSString *DPVerifyShowWithSidebar(DPPatch *patch) {
    for (NSView *pane in DPFindViews(DPDiaContentPane)) {
        DPToolbarHover *hover = [DPToolbarHover forPane:pane];
        NSView *bar = DPSubview(pane, DPDiaToolbar);
        if (!DPHideToolbar.on || !bar || bar.hiddenOrHasHiddenAncestor || hover.revealed) continue;
        BOOL shown = patch->on && DPSidebarDocked(pane);
        if (shown && bar.alphaValue < 0.99) return @"toolbar stays hidden while the sidebar is open";
        if (!shown && bar.alphaValue > 0.01) return @"toolbar shows while the sidebar is closed";
    }
    return nil;
}

DP_PATCH(DPShowToolbarWithSidebar) {
    .key = @"showToolbarWithSidebar",
    .order = 45,
    .title = @"Show toolbar with the sidebar",
    .detail = @"Bring the hidden toolbar back while the sidebar is open, and hide it again when the sidebar closes.",
    .symbol = @"sidebar.left",
    .tint = @"systemIndigoColor",
    .requires = @"hideToolbar",
    .apply = DPApplyShowWithSidebar,
    .verify = DPVerifyShowWithSidebar,
};
