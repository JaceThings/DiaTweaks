#import "LittleDia.h"
#import "Patches/HideToolbar/HideToolbar.h"

static const NSSize DPLittleSize = {860, 640};
static const NSTimeInterval DPLittleReadyPoll = 1.0 / 60, DPLittleReadyTimeout = 0.6;
static const CGFloat DPLittleOriginWidth = 160, DPLittlePopScale = 0.92;
static const CGFloat DPPopoverWidthFraction = 0.82, DPPopoverHeightFraction = 0.86, DPPopoverMaxWidth = 1200;

// Collects windows Dia creates while making a little window. They start out invisible: Dia orders new windows in
// through paths that skip the public ordering methods, so hiding at creation is the only way no frame of the
// full-size window, sidebar open, reaches the screen. Anything else made meanwhile, like a tooltip, is restored.
static NSMutableArray<NSWindow *> *DPWindowsMadeForLittle;

static void DPCollect(NSWindow *window) {
    if (!window || !DPWindowsMadeForLittle) return;
    window.alphaValue = 0;
    if (![DPWindowsMadeForLittle containsObject:window]) [DPWindowsMadeForLittle addObject:window];
}

static id DPWindow_init(NSWindow *self, SEL _cmd, NSRect rect, NSWindowStyleMask style, NSBackingStoreType backing, BOOL defer, NSScreen *screen) {
    NSWindow *window = DPCallOriginal(DPWindow_init, self, rect, style, backing, defer, screen);
    DPCollect(window);
    return window;
}

// Swift subclasses may come in through either designated initializer.
static id DPWindow_initNoScreen(NSWindow *self, SEL _cmd, NSRect rect, NSWindowStyleMask style, NSBackingStoreType backing, BOOL defer) {
    NSWindow *window = DPCallOriginal(DPWindow_initNoScreen, self, rect, style, backing, defer);
    DPCollect(window);
    return window;
}

void DPInstallLittleWindowHooks(void) {
    DPHookClass(NSWindow.class, @selector(initWithContentRect:styleMask:backing:defer:screen:), (IMP)DPWindow_init);
    DPHookClass(NSWindow.class, @selector(initWithContentRect:styleMask:backing:defer:), (IMP)DPWindow_initNoScreen);
}

// Reveals the window once Dia has finished collapsing its sidebar, or after a moment if it never reports back.
static void DPWhenLittleReady(NSWindow *window, NSURL *url, NSRect frame, DPLittleTransition *transition) {
    CFTimeInterval start = CACurrentMediaTime();
    [NSTimer scheduledTimerWithTimeInterval:DPLittleReadyPoll repeats:YES block:^(NSTimer *timer) {
        if (!NSEqualRects(window.frame, frame)) [window setFrame:frame display:YES];
        if (DPLittleSidebarHeader(window) && CACurrentMediaTime() - start < DPLittleReadyTimeout) return;
        [timer invalidate];
        DPLittleOpening = NO;
        [transition windowReady:window id:DPLittleID(window) url:url];
    }];
}

static void DPShowLittle(NSWindow *window, NSWindow *parent, NSRect frame) {
    window.alphaValue = 0;
    [window setFrame:frame display:YES];
    DPAttachLittle(window, parent);
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:nil];
}

// Makes a new little window, closing any old one. Returns nil if Dia didn't make one.
static NSWindow *DPMakeLittle(NSURL *url) {
    for (NSWindow *old in DPLittleWindows.allObjects)
        if (DPLittleID(old)) DPDiaScript([NSString stringWithFormat:@"close window id %@", DPQuoted(DPLittleID(old))]);
    NSSet<NSWindow *> *before = [NSSet setWithArray:NSApp.windows];
    DPWindowsMadeForLittle = [NSMutableArray new];
    NSString *body = url ? [NSString stringWithFormat:@"set w to make new window\nset URL of active tab of w to %@\nreturn id of w", DPQuoted(url.absoluteString)]
                         : @"return id of (make new window)";
    NSString *windowID = DPDiaScript(body).stringValue;
    NSWindow *window = nil;
    for (NSWindow *w in NSApp.windows) if (![before containsObject:w] && w.canBecomeMainWindow) { window = w; break; }
    for (NSWindow *w in DPWindowsMadeForLittle) if (w != window) w.alphaValue = 1;
    DPWindowsMadeForLittle = nil;
    if (!windowID || !window) return nil;
    DPSetLittleID(window, windowID);
    [DPLittleWindows addObject:window];
    // Little Dia never shows its toolbar, whether or not Hide toolbar is on.
    [DPToolbarlessWindows addObject:window];
    DPRelayoutPanes();
    DPLittle = window;
    [DPLittleDefaults setObject:windowID forKey:DPLittleWindowIDKey];
    DPAddMoveButton(window);
    return window;
}

// From the pointer for links, since that's where the click was; a small pop from the centre for the shortcut.
void DPOpenLittleDia(NSURL *url, BOOL fromPointer, void (^fallback)(void)) {
    NSPoint mouse = NSEvent.mouseLocation;
    NSWindow *parent = DPLittleParent();
    NSScreen *screen = parent.screen ?: NSScreen.mainScreen;
    if (!parent) for (NSScreen *s in NSScreen.screens) if (NSMouseInRect(mouse, s.frame, NO)) screen = s;
    // Over the window in use, like a popover; centred on the screen when Dia has no window to open over.
    NSRect area = parent ? parent.frame : screen.visibleFrame;
    NSSize size = parent ? NSMakeSize(MIN(round(NSWidth(area) * DPPopoverWidthFraction), DPPopoverMaxWidth), round(NSHeight(area) * DPPopoverHeightFraction))
                         : NSMakeSize(MIN(DPLittleSize.width, NSWidth(area) - 40), MIN(DPLittleSize.height, NSHeight(area) - 40));
    NSRect frame = NSMakeRect(round(NSMidX(area) - size.width / 2), round(NSMidY(area) - size.height / 2), size.width, size.height);
    NSPoint origin = fromPointer ? mouse : NSMakePoint(NSMidX(frame), NSMidY(frame));
    CGFloat scale = fromPointer ? DPLittleOriginWidth / size.width : DPLittlePopScale;
    DPLittleTransition *transition = [[DPLittleTransition alloc] initFrom:origin scale:scale to:frame on:screen label:url.host];

    // On the next turn, so the card is already moving while Dia builds the window.
    dispatch_async(dispatch_get_main_queue(), ^{
        DPLittleOpening = YES;
        // A link loads into the hidden Little Dia. The shortcut wants Dia's New Tab page, which only a new window opens on.
        NSWindow *window = DPLittle;
        BOOL reused = url && DPLittleAlive(window)
            && DPDiaScript([NSString stringWithFormat:@"set URL of active tab of window id %@ to %@", DPQuoted(DPLittleID(window)), DPQuoted(url.absoluteString)]);
        if (!reused) window = DPMakeLittle(url);
        if (!window) {
            DPLittleOpening = NO;
            [transition cancel];
            if (fallback) fallback();
            return;
        }
        DPShowLittle(window, parent, frame);
        if (!reused) DPCollapseSidebar(window);
        DPWhenLittleReady(window, url, frame, transition);
    });
}
