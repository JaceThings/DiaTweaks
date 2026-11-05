#import "CompactSidebar.h"

// ⌘S (View › Auto-Hide Tabs) would dock the whole sidebar again. With the strip on, it slides the strip out of the
// window and back instead, staying in Auto-Hide Tabs, where Dia shows the sidebar once the pointer reaches the edge.
static const NSTimeInterval DPSlideDuration = 0.25;  // As hide toolbar moves the toolbar, so the two move as one.
static char DPHiddenKey, DPSlideKey, DPSlideTimerKey, DPSlideDistanceKey;

BOOL DPStripHiddenIn(NSWindow *window) { return window && [DPGet(window, &DPHiddenKey) boolValue]; }
BOOL DPStripSliding(NSWindow *window) { return window && DPGet(window, &DPSlideKey) != nil; }
BOOL DPStripPresent(NSWindow *window) { return DPStripShown(window) || DPStripSliding(window); }

CGFloat DPStripVisible(NSWindow *window) {
    NSNumber *slide = DPGet(window, &DPSlideKey);
    return slide ? slide.doubleValue : DPStripShown(window) ? 1 : 0;
}

// Far enough that the window buttons and the downloads button, which reach past the strip, leave the window too.
CGFloat DPStripSlideDistance(NSWindow *window) {
    NSNumber *distance = DPGet(window, &DPSlideDistanceKey);
    return distance ? distance.doubleValue : DPStripWidth;
}

static BOOL DPIsAutoHideItem(NSMenuItem *item) {
    NSEventModifierFlags mods = NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl;
    return [item.title hasPrefix:@"Auto-Hide Tabs"]
        || ([item.keyEquivalent isEqualToString:@"s"] && (item.keyEquivalentModifierMask & mods) == NSEventModifierFlagCommand);
}

// The strip slides out, or in, while the page's edge follows it, frame by frame and on the same curve as hide toolbar
// moves the toolbar and page, so they move as one. Dia gets the sidebar back, parked, once the strip is out of sight.
static void DPSlideStrip(NSView *host, BOOL hide) {
    NSWindow *window = host.window;
    CGFloat from = DPStripVisible(window), to = hide ? 0 : 1;
    if (!DPStripSliding(window)) {
        CGFloat lights = hide ? DPHeaderButtonsRight(window) : [DPGet(window, &DPSlideDistanceKey) doubleValue];
        DPSet(window, &DPSlideDistanceKey, @(MAX(DPStripWidth, ceil(lights) + 2)));
    }
    [(NSTimer *)DPGet(window, &DPSlideTimerKey) invalidate];
    DPSet(window, &DPHiddenKey, @(hide));  // Hide toolbar follows this, so it starts now too.
    DPMatchStripToolbar(hide);
    void (^step)(CGFloat) = ^(CGFloat visible) {
        DPSet(window, &DPSlideKey, @(visible));
        DPPlaceHost(host);
        DPRelayoutCompactPanes(window);
        DPClearLightsIn(window);
    };
    step(from);
    CFTimeInterval start = CACurrentMediaTime();
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *t) {
        CGFloat p = MIN(1, (CACurrentMediaTime() - start) / DPSlideDuration);
        step(from + (to - from) * p * p * (3 - 2 * p));
        if (p < 1) return;
        [t invalidate];
        DPSet(window, &DPSlideKey, nil);
        DPPlaceHost(host);
        DPRefreshWindow(window);
    }];
    DPSet(window, &DPSlideTimerKey, timer);
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    DPRefreshWindow(window);
}

// Dia's front browser window, even while Settings or another app is in front.
static NSWindow *DPBrowserWindow(void) {
    NSWindow *window = NSApp.mainWindow;
    for (NSWindow *each in NSApp.orderedWindows)
        if (!DPHostIn(window) && DPHostIn(each)) window = each;
    return DPHostIn(window) ? window : nil;
}

static void DPItem_performWithSender(NSMenuItem *self, SEL _cmd, id sender) {
    NSWindow *window = DPBrowserWindow();
    NSView *host = DPHostIn(window);
    if (!DPCompactSidebar.on || !DPIsAutoHideItem(self) || !DPDiaParked(host))
        return DPCallOriginal(DPItem_performWithSender, self, sender);
    DPSlideStrip(host, !DPStripHiddenIn(window));
}

// The toolbar's sidebar button docks the sidebar, as ⌘S would; with the strip on, it slides the strip like ⌘S instead.
static BOOL DPIsSidebarButton(NSView *view) {
    if (view.class != objc_getClass(DPDiaHoverableControl) || ![view.accessibilityLabel isEqualToString:@"Toggle sidebar"]) return NO;
    for (NSView *up = view.superview; up; up = up.superview)
        if (DPIsKind(up, DPDiaToolbar)) return YES;
    return NO;
}

static BOOL DPTakesSidebarButton(NSView *button) {
    return DPCompactSidebar.on && DPIsSidebarButton(button) && DPDiaParked(DPHostIn(button.window));
}

static void DPButton_mouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    if (!DPTakesSidebarButton(self)) DPCallOriginal(DPButton_mouseDown, self, event);
}

static void DPButton_mouseUp(NSView *self, SEL _cmd, NSEvent *event) {
    if (!DPTakesSidebarButton(self)) return DPCallOriginal(DPButton_mouseUp, self, event);
    if (!NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) return;
    NSView *host = DPHostIn(self.window);
    DPSlideStrip(host, !DPStripHiddenIn(self.window));
}

static NSMenuItem *DPAutoHideItemIn(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        NSMenuItem *found = DPIsAutoHideItem(item) ? item : item.submenu ? DPAutoHideItemIn(item.submenu) : nil;
        if (found) return found;
    }
    return nil;
}

// Turning the patch on puts the front window into Auto-Hide Tabs, where the strip shows; turning it off docks the sidebar
// again, through Dia's own command, rather than leaving the window without one.
void DPMatchAutoHide(BOOL on) {
    NSWindow *window = DPBrowserWindow();
    NSView *host = DPHostIn(window);
    NSMenuItem *item = DPAutoHideItemIn(NSApp.mainMenu);
    if (window) DPSet(window, &DPHiddenKey, nil);
    DPMatchStripToolbar(NO);
    if (!host || !item || DPDiaParked(host) == on) return;
    // Dia's command acts on the main window, which is Settings while its switch is flipped; the browser window is main
    // just for it, without coming forward.
    NSWindow *main = NSApp.mainWindow;
    if (main != window && window.canBecomeMainWindow) [window makeMainWindow];
    [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
    if (main && main != window && main.canBecomeMainWindow) [main makeMainWindow];
}

void DPInstallCompactShortcut(void) {
    DPHook(DPDiaCallbackMenuItem, NSSelectorFromString(@"performWithSender:"), (IMP)DPItem_performWithSender);
    DPHook(DPDiaHoverableControl, @selector(mouseDown:), (IMP)DPButton_mouseDown);
    DPHook(DPDiaHoverableControl, @selector(mouseUp:), (IMP)DPButton_mouseUp);
}
