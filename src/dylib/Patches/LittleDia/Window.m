#import "LittleDia.h"
#import <objc/message.h>

static char DPLittleKey, DPPageKey, DPChromeKey, DPSourceKey, DPPromotedKey;
static NSDate *DPExpectedUntil;
static void (^DPMissed)(void);  // What to do if the window doesn't come.
static id DPPendingPage;                   // A popup's page that came before its window.
static __weak NSWindow *DPWindowAwaitingPage;  // A popup's window that came before its page.

static BOOL DPExpecting(void) { return DPExpectedUntil && DPExpectedUntil.timeIntervalSinceNow > 0; }

void DPExpectLittleDiaWindow(void (^missed)(void)) {
    DPExpectedUntil = [NSDate dateWithTimeIntervalSinceNow:3];
    DPPendingPage = nil;
    DPWindowAwaitingPage = nil;
    void (^this)(void) = DPMissed = [missed copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (DPMissed != this) return;
        DPMissed = nil;
        DPExpectedUntil = nil;
        this();
    });
}

BOOL DPIsLittleDiaWindow(NSWindow *window) { return window && [DPGet(window, &DPLittleKey) boolValue]; }

id DPLittleDiaPage(NSWindow *window) { return DPGet(window, &DPPageKey); }

// Takes away the title bar: the content runs under it, so Dia's popup bar, pinned to the top, is the top of the window.
static void DPSetChrome(NSWindow *window, BOOL little) {
    NSView *titlebar = [window standardWindowButton:NSWindowCloseButton].superview.superview;
    if (little && !DPGet(window, &DPChromeKey)) {
        DPSet(window, &DPChromeKey, @{@"mask" : @(window.styleMask), @"movable" : @(window.movableByWindowBackground)});
        window.styleMask |= NSWindowStyleMaskFullSizeContentView;
    } else if (!little && DPGet(window, &DPChromeKey)) {
        NSDictionary *saved = DPGet(window, &DPChromeKey);
        DPSet(window, &DPChromeKey, nil);
        window.styleMask = [saved[@"mask"] unsignedIntegerValue];
        window.movableByWindowBackground = [saved[@"movable"] boolValue];
    } else return;
    window.titlebarAppearsTransparent = little;
    window.titleVisibility = little ? NSWindowTitleHidden : NSWindowTitleVisible;
    if (little) window.movableByWindowBackground = YES;
    for (NSWindowButton kind = NSWindowCloseButton; kind <= NSWindowZoomButton; kind++) [window standardWindowButton:kind].hidden = little;
    titlebar.hidden = little;
}

// Claims a popup that appears while a link is on its way. Pages open popups too, but not in the same second.
static void DPClaim(NSWindow *window) {
    if (!window || !DPIsKind(window, DPDiaPopupWindow) || DPGet(window, &DPLittleKey) || !DPExpecting()) return;
    DPExpectedUntil = nil;
    DPMissed = nil;
    DPSet(window, &DPLittleKey, @YES);
    if (DPLinkSource()) DPSet(window, &DPSourceKey, @(DPLinkSource()));
    if (DPPendingPage) DPSet(window, &DPPageKey, DPPendingPage);
    else DPWindowAwaitingPage = window;
    DPPendingPage = nil;
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    DPRestoreStack(window);
    // Chromium focuses the new window a moment later, which can bring Dia's windows forward again.
    __weak NSWindow *weakWindow = window;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        DPRestoreStack(weakWindow);
        DPFinishStack();
    });
    DPRefreshLittleDiaWindows();
}

// Chromium hands Dia each popup's page here, with the popup's own browser.
static void DPBrowser_didCreate(id self, SEL _cmd, id browser, id page, BOOL active) {
    DPCallOriginal(DPBrowser_didCreate, self, browser, page, active);
    long (*type)(id, SEL) = (void *)objc_msgSend;
    if (!page || ![browser respondsToSelector:@selector(type)] || type(browser, @selector(type)) != 2) return;  // 2: a popup
    NSWindow *waiting = DPWindowAwaitingPage;
    if (waiting) {
        DPWindowAwaitingPage = nil;
        DPSet(waiting, &DPPageKey, page);
        DPRefreshLittleDiaWindows();
    } else if (DPExpecting()) DPPendingPage = page;
}

static void DPPopupBar_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPopupBar_viewDidMoveToWindow, self);
    DPClaim(self.window);
}

void DPPromoteLittleDiaWindow(NSWindow *window) { DPSet(window, &DPPromotedKey, @YES); }

// Where the page went: Dia's front browser window comes forward.
static void DPShowMainWindow(void) {
    for (NSWindow *window in NSApp.orderedWindows)
        if (DPIsKind(window, DPDiaWindow) && window.visible) {
            [NSApp activateIgnoringOtherApps:YES];
            [window makeKeyAndOrderFront:nil];
            return;
        }
}

void DPRefreshLittleDiaWindows(void) {
    for (NSWindow *window in NSApp.windows)
        if (DPIsLittleDiaWindow(window)) DPSetChrome(window, DPLittleDia.on);
    DPRelayoutLittleDiaBars();
}

void DPInstallLittleDiaWindows(void) {
    DPHookClass(objc_getClass(DPDiaPopupBar), @selector(viewDidMoveToWindow), (IMP)DPPopupBar_viewDidMoveToWindow);
    DPHook(DPDiaBrowserDelegate, @selector(browser:didCreateNewWebContents:isActive:), (IMP)DPBrowser_didCreate);
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { DPClaim(note.object); }];
    // Open in Dia goes to the main window. Otherwise, closed while in front, by ✕, ⌘W or Escape: back to the app the
    // link came from.
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) {
                                                    NSWindow *window = note.object;
                                                    if (!DPLittleDia.on || !DPIsLittleDiaWindow(window)) return;
                                                    pid_t source = [DPGet(window, &DPSourceKey) intValue];
                                                    if ([DPGet(window, &DPPromotedKey) boolValue])
                                                        dispatch_async(dispatch_get_main_queue(), ^{ DPShowMainWindow(); });
                                                    else if (window.isKeyWindow && source)
                                                        dispatch_async(dispatch_get_main_queue(), ^{ DPReturnToSource(source); });
                                                }];
    DPInstallLittleDiaBar();
    DPInstallLittleDiaStack();
}
