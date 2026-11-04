#import "CompactSidebar.h"

// While hide toolbar keeps the toolbar out of sight, the window buttons have no toolbar to sit over. Pointing at the top
// of the strip, above its tabs, shows them: the strip widens to fit them as they fade in.
static const NSTimeInterval DPRevealDuration = 0.25, DPConcealDelay = 0.3;
static char DPRevealKey, DPRevealTimerKey, DPConcealTimerKey, DPRoomKey;
static id DPMonitor;

CGFloat DPLightsReveal(NSWindow *window) { return window ? [DPGet(window, &DPRevealKey) doubleValue] : 0; }

// How much wider than the strip the window buttons need it, with as much room right of them as left. Measured while
// they're hidden: as the strip widens, the header lays them out again, and a room that followed them would widen the
// strip again, and on.
CGFloat DPRevealRoom(NSWindow *window) {
    if (!window) return 0;
    NSNumber *kept = DPGet(window, &DPRoomKey);
    if (kept && DPLightsReveal(window) > 0) return kept.doubleValue;
    CGFloat lights = DPLightsRight(window), room = lights > 0 ? MAX(0, ceil(lights + DPLightsLeft(window)) - DPStripWidth) : 0;
    if (room != kept.doubleValue || !kept) DPSet(window, &DPRoomKey, @(room));
    return room;
}

// Only while the strip shows and hide toolbar keeps the toolbar, and the window buttons over it, out of sight.
static BOOL DPRevealable(NSWindow *window) {
    return DPStripShown(window) && !DPStripSliding(window) && !DPStripExpanded(DPHostIn(window)) && DPToolbarHidden(window);
}

static void DPApplyReveal(NSWindow *window) {
    NSView *host = DPHostIn(window), *root = DPSidebarRootIn(window);
    DPPlaceHost(host);
    DPPlaceListIn(window);
    DPSubview(root, DPDiaSidebarHeader).needsLayout = YES;
}

static void DPReveal(NSWindow *window, BOOL show) {
    CGFloat from = DPLightsReveal(window), to = show && DPRevealable(window) ? 1 : 0;
    NSTimer *running = DPGet(window, &DPRevealTimerKey);
    if (from == to && !running) return;
    [running invalidate];
    CFTimeInterval start = CACurrentMediaTime();
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *t) {
        CGFloat p = MIN(1, (CACurrentMediaTime() - start) / DPRevealDuration);
        DPSet(window, &DPRevealKey, @(from + (to - from) * p * p * (3 - 2 * p)));
        DPApplyReveal(window);
        if (p < 1) return;
        [t invalidate];
        DPSet(window, &DPRevealTimerKey, nil);
    }];
    DPSet(window, &DPRevealTimerKey, timer);
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

// The top of the strip, where the window buttons go, and once they show, as far right as they reach.
static BOOL DPPointerOnLights(NSWindow *window) {
    NSView *host = DPHostIn(window);
    NSPoint p = window.mouseLocationOutsideOfEventStream;
    CGFloat top = NSHeight(window.contentView.superview.bounds), width = DPStripWidth + DPRevealRoom(window) * DPLightsReveal(window);
    return host && p.x >= 0 && p.x < width && p.y <= top && p.y > DPToolbarBottom(window);
}

static void DPTrack(NSWindow *window) {
    if (!DPHostIn(window)) return;
    BOOL on = DPRevealable(window) && DPPointerOnLights(window);
    NSTimer *conceal = DPGet(window, &DPConcealTimerKey);
    if (on) {
        [conceal invalidate];
        DPSet(window, &DPConcealTimerKey, nil);
        if (DPLightsReveal(window) < 1 && !DPGet(window, &DPRevealTimerKey)) DPReveal(window, YES);
        return;
    }
    if (DPLightsReveal(window) == 0 || conceal) return;
    __weak NSWindow *weakWindow = window;
    DPSet(window, &DPConcealTimerKey, [NSTimer scheduledTimerWithTimeInterval:DPConcealDelay repeats:NO block:^(NSTimer *t) {
        NSWindow *strong = weakWindow;
        DPSet(strong, &DPConcealTimerKey, nil);
        if (!(DPRevealable(strong) && DPPointerOnLights(strong))) DPReveal(strong, NO);
    }]);
}

// Dia fades the window buttons in itself as the pointer nears them while tabs auto-hide; on the strip, only the toolbar
// and the reveal decide.
static void DPLights_setAlphaValue(NSView *self, SEL _cmd, CGFloat alpha) {
    NSWindow *window = self.window;
    if (DPStripPresent(window) && !DPStripExpanded(DPHostIn(window))) alpha = MAX(DPToolbarAlpha(window), DPLightsReveal(window));
    DPCallOriginal(DPLights_setAlphaValue, self, alpha);
}

// Hide toolbar shows the toolbar again, or the strip goes: the window buttons are back over the toolbar, or gone.
void DPSettleReveal(NSWindow *window) {
    if (DPLightsReveal(window) > 0 && !DPRevealable(window)) DPReveal(window, NO);
}

void DPInstallCompactReveal(void) {
    DPHook(DPDiaTrafficLights, @selector(setAlphaValue:), (IMP)DPLights_setAlphaValue);
    DPMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved | NSEventMaskMouseExited | NSEventMaskMouseEntered
                                                      handler:^NSEvent *(NSEvent *event) {
        if (DPCompactSidebar.on && event.window) DPTrack(event.window);
        return event;
    }];
}
