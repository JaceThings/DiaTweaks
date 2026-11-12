#import "HideToolbar.h"

extern DPPatch DPToolbarBesideSidebar;

CGFloat DPToolbarInset(NSView *pane, NSRect bar) {
    CGFloat inset = 0;
    if (DPToolbarBesideSidebar.progress == 0) return 0;
    for (NSView *sidebar in DPFindViews(DPDiaFloatingSidebar)) {
        if (sidebar.window != pane.window || sidebar.hiddenOrHasHiddenAncestor) continue;
        NSRect over = [pane convertRect:sidebar.bounds fromView:sidebar];
        if (NSIntersectsRect(over, bar)) inset = MAX(inset, NSMaxX(over) - NSMinX(bar));
    }
    return MIN(inset, NSWidth(bar) / 2) * DPToolbarBesideSidebar.progress;
}

static void DPSidebarMoved(void) {
    if (DPToolbarBesideSidebar.progress > 0) for (NSView *pane in DPPanes.allObjects) DPApplyToolbar(pane);
}

// Dia keeps the floating sidebar in the window: it slides it by frame, off the left edge, and hides it.
static void DPFloatingSidebar_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPCallOriginal(DPFloatingSidebar_setFrame, self, frame);
    DPSidebarMoved();
}

static void DPFloatingSidebar_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPFloatingSidebar_setHidden, self, hidden);
    DPSidebarMoved();
}

static void DPInstallBesideSidebar(void) {
    DPHook(DPDiaFloatingSidebar, @selector(setFrame:), (IMP)DPFloatingSidebar_setFrame);
    DPHook(DPDiaFloatingSidebar, @selector(setHidden:), (IMP)DPFloatingSidebar_setHidden);
}

static NSString *DPVerifyBesideSidebar(DPPatch *patch) {
    for (NSView *pane in DPFindViews(DPDiaContentPane)) {
        NSView *bar = DPSubview(pane, DPDiaToolbar);
        NSRect laidOut = bar ? DPLaidOutFrame(bar) : NSZeroRect;
        CGFloat inset = DPToolbarInset(pane, laidOut);
        if (bar && fabs(NSMinX(bar.frame) - NSMinX(laidOut) - inset) > 0.5) return inset ? @"floating sidebar covers the toolbar" : @"toolbar doesn't start at its left edge";
    }
    return nil;
}

DP_PATCH(DPToolbarBesideSidebar) {
    .key = @"toolbarBesideSidebar",
    .order = 49,
    .title = @"Toolbar Beside Floating Sidebar",
    .detail = @"With the sidebar hidden, start the toolbar where the floating sidebar ends instead of underneath it, as with the sidebar open. Most useful in full screen, where the top of the screen opens both.",
    .symbol = @"sidebar.squares.left",
    .tint = @"systemIndigoColor",
    .section = @"Toolbar",
    .classes = DPClasses(DPDiaFloatingSidebar, DPDiaToolbar, DPDiaContentPane),
    .install = DPInstallBesideSidebar,
    .verify = DPVerifyBesideSidebar,
};
