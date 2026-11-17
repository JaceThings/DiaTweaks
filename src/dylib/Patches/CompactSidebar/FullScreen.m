#import "CompactSidebar.h"

// In full screen the strip steps aside, and Dia's own Auto-Hide Tabs shows the sidebar from the window's edge. macOS
// moves the window buttons into the menu bar's window there, and a page in full screen covers the toolbar, so the strip
// would sit over the page with the buttons stuck to it, and leave the window without its page once full screen ends.
static char DPFullScreenKey;

BOOL DPInFullScreen(NSWindow *window) {
    if (!window) return NO;
    NSNumber *going = DPGet(window, &DPFullScreenKey);  // Set ahead of each change, as the style mask flips only after.
    return going ? going.boolValue : (window.styleMask & NSWindowStyleMaskFullScreen) != 0;
}

// The strip shows or goes, and with it the page's place, the toolbar's buttons, the window buttons and the tabs, all
// at once. macOS doesn't lay a window out while it animates it in or out of full screen, so it's laid out here: the
// header first, at the strip's width or the sidebar's, as the toolbar's buttons make room for what's in it.
static void DPRefreshFullScreen(NSWindow *window) {
    NSView *host = DPHostIn(window), *root = DPSidebarRootIn(window), *frameView = window.contentView.superview;
    if (!host) return;
    DPNow(^{
        DPPlaceHost(host);
        NSView *header = DPSubview(root, DPDiaSidebarHeader);
        header.needsLayout = YES;
        [header layoutSubtreeIfNeeded];
        DPRefreshWindow(window);
        DPPlaceListIn(window);
        root.needsLayout = YES;
        for (NSView *pane in DPFindViews(DPDiaContentPane)) if (pane.window == window) pane.needsLayout = YES;
        [frameView layoutSubtreeIfNeeded];
        DPClearLightsIn(window);
    });
}

static void DPGoing(NSWindow *window, BOOL inFullScreen) {
    if (!DPHostIn(window)) return;
    DPSet(window, &DPFullScreenKey, @(inFullScreen));
    DPRefreshFullScreen(window);
}

// Dia's "press Escape to exit full screen" toast is a window of its own over this one, which lingers, half drawn, while
// macOS animates the window out of full screen; it goes as full screen ends instead.
static void DPHideToasts(NSWindow *window) {
    for (NSWindow *child in NSApp.windows)
        if (DPIsKind(child.contentView, DPDiaToastClip) && (!child.parentWindow || child.parentWindow == window)) child.alphaValue = 0;
}

static void DPShowToasts(NSWindow *window) {
    for (NSWindow *child in NSApp.windows)
        if (DPIsKind(child.contentView, DPDiaToastClip) && (!child.parentWindow || child.parentWindow == window)) child.alphaValue = 1;
}

// macOS takes its picture of the window to animate as it starts going in or out, before the notification, so the strip
// goes or comes back first; a page asking for full screen, or Escape leaving it, comes through here too.
static void DPWindow_toggleFullScreen(NSWindow *self, SEL _cmd, id sender) {
    BOOL entering = !(self.styleMask & NSWindowStyleMaskFullScreen);
    if (!entering) DPHideToasts(self);
    if (DPCompactSidebar.on && DPHostIn(self) && DPDiaParked(DPHostIn(self)) && !DPStripHiddenIn(self)) {
        DPGoing(self, entering);
        [self displayIfNeeded];
        [CATransaction flush];
    }
    DPCallOriginal(DPWindow_toggleFullScreen, self, sender);
}

static void DPObserve(NSNotificationName name, BOOL inFullScreen) {
    [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSWindow *window = note.object;
        if (![window isKindOfClass:NSWindow.class]) return;
        if (name == NSWindowWillExitFullScreenNotification) DPHideToasts(window);
        if (name == NSWindowDidExitFullScreenNotification) {  // Ready for the next one, once this one has gone.
            __weak NSWindow *weakWindow = window;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ DPShowToasts(weakWindow); });
        }
        DPGoing(window, inFullScreen);
        // AppKit flips the style mask just after each will, and lays the window out again after each did.
        __weak NSWindow *weakWindow = window;
        dispatch_async(dispatch_get_main_queue(), ^{ if (DPHostIn(weakWindow)) DPRefreshFullScreen(weakWindow); });
    }];
}

void DPInstallCompactFullScreen(void) {
    DPHookClass(NSWindow.class, @selector(toggleFullScreen:), (IMP)DPWindow_toggleFullScreen);
    DPObserve(NSWindowWillEnterFullScreenNotification, YES);
    DPObserve(NSWindowDidEnterFullScreenNotification, YES);
    DPObserve(NSWindowWillExitFullScreenNotification, NO);
    DPObserve(NSWindowDidExitFullScreenNotification, NO);
}
