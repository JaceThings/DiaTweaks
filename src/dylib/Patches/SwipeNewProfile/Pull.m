#import "Patches/SwipeNewProfile/SwipeNewProfile.h"

// How far past the last profile to pull before letting go opens New Profile.
static const CGFloat DPPullDistance = 280;

// One swipe at a time, starting on the last profile. DPPulled is how far past its edge the swipe is. While
// Dia has the swipe, a timer samples its events; once the pull is under way the swipe is ours.
static __weak NSWindow *DPPullWindow;
static __weak NSView *DPPullSidebar;
static DPPullIndicator *DPIndicator;
static NSTimer *DPPullTimer;
static CGFloat DPPulled, DPUpDown;
static NSTimeInterval DPLastEvent;
static CFTimeInterval DPPullStart;
static BOOL DPOwned, DPSawLoop, DPSwallowMomentum;
static NSEvent *DPPosted;

BOOL DPIsPullIndicator(NSView *view) { return [view isKindOfClass:DPPullIndicator.class] && view != DPIndicator; }

void DPEndPull(BOOL open) {
    NSWindow *window = DPPullWindow;
    DPSwallowMomentum = DPOwned;  // The taken swipe's momentum would scroll the tabs.
    DPOwned = NO;
    DPPosted = nil;
    [DPPullTimer invalidate];
    DPPullTimer = nil;
    [DPIndicator finish:open];
    DPIndicator = nil;
    DPPullWindow = nil;
    if (open) DPOpenNewProfile(window);
}

static void DPPullBy(CGFloat deltaX) {
    // Toward the next profile the content moves left, whichever way the user's scrolling runs.
    DPPulled -= deltaX;
    NSView *sidebar = DPPullSidebar;
    if (DPIndicator || DPPulled <= 0 || !sidebar.window) return;
    DPIndicator = [[DPPullIndicator alloc] initWithFrame:sidebar.bounds];
    [sidebar addSubview:DPIndicator];
}

// Dia reads a swipe's events in a loop of its own, so while it pages this samples the event it's on each frame.
// The loop runs in the event tracking mode; back in the default mode, the fingers have lifted.
static void DPTrackPull(void) {
    NSWindow *window = DPPullWindow;
    if (!DPSwipeNewProfile.on || !window.isVisible || CACurrentMediaTime() - DPPullStart > 15) return DPEndPull(NO);
    [DPIndicator pullTo:MAX(0, DPPulled) / DPPullDistance];  // Every frame, so it eases even between events.
    if (DPOwned) return;
    if ([NSRunLoop.currentRunLoop.currentMode isEqualToString:NSDefaultRunLoopMode]) {
        // Not paging at all, as with a vertical scroll, once Dia has had a moment to start.
        if (DPSawLoop || CACurrentMediaTime() - DPPullStart > 0.3) DPEndPull(DPIndicator.full);
        return;
    }
    DPSawLoop = YES;
    NSEvent *event = NSApp.currentEvent;
    if (event.type != NSEventTypeScrollWheel || event == DPPosted || event.timestamp == DPLastEvent || event.phase != NSEventPhaseChanged) return;
    DPLastEvent = event.timestamp;
    DPUpDown += fabs(event.scrollingDeltaY);
    DPPullBy(event.scrollingDeltaX);
    // Past the edge, and mostly sideways: cancel Dia's swipe and keep the rest of it from Dia, so swiping back
    // only takes the + away.
    if (DPPulled > 12 && DPPulled > DPUpDown) {
        DPOwned = YES;
        DPPosted = DPCancelDiaSwipe();
    }
}

void DPStartPull(NSEvent *event, NSView *sidebar) {
    DPPullWindow = event.window;
    DPPullSidebar = sidebar;
    DPPulled = DPUpDown = 0;
    DPOwned = DPSawLoop = NO;
    DPLastEvent = event.timestamp;
    DPPullStart = CACurrentMediaTime();
    DPPullTimer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *timer) { DPTrackPull(); }];
    [NSRunLoop.mainRunLoop addTimer:DPPullTimer forMode:NSRunLoopCommonModes];
}

// Every scroll event the monitor sees. Returns nil for those it keeps from Dia.
NSEvent *DPPullEvent(NSEvent *event, BOOL *handled) {
    *handled = YES;
    BOOL starts = event.phase == NSEventPhaseBegan || event.phase == NSEventPhaseMayBegin;
    if (event == DPPosted) return event;
    if (starts) DPSwallowMomentum = NO;
    if (event.momentumPhase != NSEventPhaseNone && DPSwallowMomentum && !DPOwned) return nil;
    // Only the swiped window's trackpad swipe is ours; a new one means the last has ended.
    if (!DPPullTimer || event.window != DPPullWindow || !event.hasPreciseScrollingDeltas || starts) {
        if (DPPullTimer && starts) DPEndPull(NO);
        *handled = NO;
        return event;
    }
    if (!DPOwned) return event;  // Dia is paging; the timer follows along.
    if (event.phase == NSEventPhaseEnded || event.phase == NSEventPhaseCancelled) {
        DPEndPull(DPIndicator.full);
        return nil;
    }
    if (event.phase == NSEventPhaseChanged) DPPullBy(event.scrollingDeltaX);
    return nil;
}
