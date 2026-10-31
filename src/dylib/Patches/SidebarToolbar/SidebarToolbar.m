#import "SidebarToolbar.h"

static BOOL DPWasDocking;

static void DPApplySidebarToolbar(DPPatch *patch) {
    DPWasDocking = DPDocking();
    DPUpdateDocks();
    DPRelayoutViews(DPSidebars);
    DPRelayoutViews(DPDockBars);
    DPRelayoutViews(DPDockPanes);
}

// The hidden toolbar takes the bar back while it's on, and gives it back once it has finished showing again.
static void DPRelayoutSidebarToolbar(void) {
    if (DPDocking() != DPWasDocking) DPApplySidebarToolbar(&DPSidebarToolbar);
}

static NSString *DPVerifySidebarToolbar(DPPatch *patch) {
    BOOL docking = patch->on && DPDocking();
    NSArray<NSView *> *panes = DPFindViews(DPDiaContentPane);
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        NSView *sidebar = header.superview;
        NSView *bar = DPSubview(sidebar, DPDiaToolbar), *split = DPSubview(sidebar, class_getName(DPSplitAddress.class));
        if (!docking || !DPSidebarShown(sidebar)) {
            if (bar || split) return @"toolbar still in the sidebar";
            continue;
        }
        NSUInteger shown = 0;
        for (NSView *pane in panes) shown += pane.window == sidebar.window && !pane.hiddenOrHasHiddenAncestor;
        if (shown == 1 && !bar) return @"toolbar isn't in the sidebar";
        if (shown > 1 && !split) return @"no address in the sidebar for the split view";
        if (bar && !NSEqualRects(bar.frame, DPDockFrame(sidebar, bar))) return @"toolbar isn't at the top of the sidebar";
    }
    for (NSView *pane in panes) {
        NSView *bar = DPPaneBar(pane);
        if (pane.hiddenOrHasHiddenAncestor || !bar || bar.superview == pane) continue;
        if (!DPIsDocked(bar)) return @"toolbar left its page";
        NSView *page = DPFindView(pane, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaContentContainer); });
        NSRect inPane = [pane convertRect:page.bounds fromView:page];
        if (page && (pane.isFlipped ? NSMinY(inPane) : NSHeight(pane.bounds) - NSMaxY(inPane)) >= NSHeight(DPPaneFrame(bar)))
            return @"page didn't move up into the toolbar's place";
    }
    return nil;
}

static void DPInstallSidebarToolbar(void) {
    DPInstallDock();
    DPInstallPane();
    DPInstallToolbar();
    DPInstallSidebar();
    DPInstallExtensions();
    DPInstallAddress();
    DPInstallSplitAddress();
    DPInstallPopovers();
}

DP_PATCH(DPSidebarToolbar) {
    .key = @"sidebarToolbar",
    .order = 45,
    .title = @"Toolbar in sidebar",
    .detail = @"Show the address, navigation buttons and extensions at the top of the sidebar, as in Arc.",
    .symbol = @"sidebar.squares.left",
    .tint = @"systemGreenColor",
    .classes = DPClasses(DPDiaToolbar, DPDiaContentPane, DPDiaSidebarHeader, DPDiaAddressBar),
    .disabledBy = @"hideToolbar",
    .install = DPInstallSidebarToolbar,
    .apply = DPApplySidebarToolbar,
    .relayout = DPRelayoutSidebarToolbar,
    .verify = DPVerifySidebarToolbar,
};
