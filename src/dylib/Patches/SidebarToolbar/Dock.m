#import "SidebarToolbar.h"
#import "Patches/HideToolbar/HideToolbar.h"

NSHashTable<NSView *> *DPSidebars, *DPDockPanes, *DPDockBars;
static NSMapTable<NSView *, NSView *> *DPHomes, *DPPaneBars;

// The hidden toolbar stays in its pane, and gives it back only once it has finished showing again.
BOOL DPDocking(void) {
    return DPSidebarToolbar.on && !DPHideToolbar.on && DPHideToolbar.progress == 0;
}

BOOL DPIsDocked(NSView *bar) {
    return bar && [DPSidebars containsObject:bar.superview];
}

NSView *DPToolbarOf(NSView *view) {
    while (view && !DPIsKind(view, DPDiaToolbar)) view = view.superview;
    return view;
}

// Hiding the sidebar slides the page over it rather than moving it, so the page's position decides.
BOOL DPSidebarShown(NSView *sidebar) {
    NSWindow *window = sidebar.window;
    NSView *page = window ? DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaContentContainer); }) : nil;
    NSRect inWindow = [sidebar convertRect:sidebar.bounds toView:nil];
    BOOL covered = page && NSMinX([page convertRect:page.bounds toView:nil]) < NSMaxX(inWindow) - NSWidth(inWindow) / 2;
    return window && !sidebar.hiddenOrHasHiddenAncestor && NSMinX(inWindow) > -NSWidth(inWindow) / 2 && !covered;
}

NSView *DPShownSidebar(NSWindow *window) {
    NSView *shown = nil;
    for (NSView *sidebar in DPSidebars) if (sidebar.window == window && DPSidebarShown(sidebar)) shown = sidebar;
    return shown;
}

// Dia keeps one pane and swaps in each tab's bar, so a pane's bar is the one Dia added last.
NSView *DPPaneBar(NSView *pane) {
    if (!pane) return nil;
    NSView *bar = DPSubview(pane, DPDiaToolbar);
    if (!bar) return [DPPaneBars objectForKey:pane];
    [DPHomes setObject:pane forKey:bar];
    [DPPaneBars setObject:bar forKey:pane];
    return bar;
}

static void DPDock(NSView *bar, NSView *sidebar) {
    NSView *pane = bar.superview;
    [sidebar addSubview:bar positioned:NSWindowAbove relativeTo:nil];
    DPSetBarFrame(bar, DPDockFrame(sidebar, bar));
    DPApplyBarAppearance(bar);
    pane.needsLayout = sidebar.needsLayout = bar.needsLayout = YES;
}

// A bar Dia has since replaced is dropped, as Dia dropped it.
static void DPUndock(NSView *bar) {
    NSView *sidebar = bar.superview, *pane = [DPHomes objectForKey:bar];
    if (DPPaneBar(pane) == bar) {
        NSView *web = pane.subviews.firstObject;
        [pane addSubview:bar positioned:web ? NSWindowAbove : NSWindowBelow relativeTo:web];
        DPSetBarFrame(bar, DPPaneFrame(bar));
        DPRestorePane(pane);
    } else {
        [bar removeFromSuperview];
    }
    DPApplyBarAppearance(bar);
    pane.needsLayout = sidebar.needsLayout = bar.needsLayout = YES;
}

void DPUndockAll(NSView *sidebar) {
    for (NSView *bar in sidebar.subviews.copy) if (DPIsKind(bar, DPDiaToolbar)) DPUndock(bar);
}

// The sidebar shows the bar of the only pane; in a split view, the focused pane's address.
void DPUpdateDock(NSWindow *window) {
    static BOOL updating;
    if (updating || !window) return;
    updating = YES;
    NSView *sidebar = DPDocking() ? DPShownSidebar(window) : nil, *only = nil, *focused = nil;
    if (sidebar) {
        NSMutableArray<NSView *> *panes = [NSMutableArray new];
        for (NSView *pane in DPDockPanes) if (pane.window == window && DPPaneBar(pane) && !pane.hiddenOrHasHiddenAncestor) [panes addObject:pane];
        if (panes.count == 1) only = panes.firstObject;
        else if (panes.count > 1) {
            NSView *focus = [window.firstResponder isKindOfClass:NSView.class] ? (NSView *)window.firstResponder : nil;
            DPSplitAddress *shown = (DPSplitAddress *)DPSubview(sidebar, class_getName(DPSplitAddress.class));
            for (NSView *pane in panes) if ([focus isDescendantOf:pane]) focused = pane;
            for (NSView *pane in panes) if (!focused && DPPaneBar(pane) == shown.bar) focused = pane;
            focused = focused ?: panes.firstObject;
        }
    }
    NSView *bar = DPPaneBar(only);
    for (NSView *candidate in DPSidebars)
        for (NSView *docked in candidate.subviews.copy)
            if (candidate.window == window && DPIsKind(docked, DPDiaToolbar) && docked != bar) DPUndock(docked);
    if (bar && bar.superview != sidebar) DPDock(bar, sidebar);
    DPShowSplitAddress(window, sidebar, DPPaneBar(focused));
    updating = NO;
}

void DPUpdateDocks(void) {
    for (NSWindow *window in NSApp.windows) DPUpdateDock(window);
}

void DPScheduleDocks(void) {
    static BOOL scheduled;
    if (scheduled) return;
    scheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        scheduled = NO;
        DPUpdateDocks();
    });
}

static BOOL DPWindow_makeFirstResponder(NSWindow *self, SEL _cmd, NSResponder *responder) {
    BOOL made = DPCallOriginal(DPWindow_makeFirstResponder, self, responder);
    if (DPSidebarToolbar.on) DPUpdateDock(self);
    return made;
}

// The page moving over the sidebar or off it changes where the bar belongs.
static void DPContainer_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPCallOriginal(DPContainer_setFrame, self, frame);
    if (DPSidebarToolbar.on) DPScheduleDocks();
}

void DPInstallDock(void) {
    DPSidebars = [NSHashTable weakObjectsHashTable];
    DPDockPanes = [NSHashTable weakObjectsHashTable];
    DPDockBars = [NSHashTable weakObjectsHashTable];
    DPHomes = [NSMapTable weakToWeakObjectsMapTable];
    DPPaneBars = [NSMapTable weakToWeakObjectsMapTable];
    DPHook(DPDiaWindow, @selector(makeFirstResponder:), (IMP)DPWindow_makeFirstResponder);
    DPHook(DPDiaContentContainer, @selector(setFrame:), (IMP)DPContainer_setFrame);
}
