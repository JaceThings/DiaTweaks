#import "Gesture.h"
DPLibraryController *DPLibraryForWindow(NSWindow *window);
static void DPLibraryPassPending(DPLibraryGesture *gesture) {
    NSArray *events = gesture.pending.copy; [gesture.pending removeAllObjects];
    gesture.nativePass = YES;
    // Replay the original prefix directly to the native window, outside the
    // application monitor. Ordinary paging must receive its Began phase too.
    for (NSEvent *event in events) [gesture.window sendEvent:event];
}
NSEvent *DPLibraryRouteScroll(NSEvent *event,DPLibraryGesture *gesture) {
    if (!DPSidebarLibrary.on) return event;
    NSWindow *window = event.window;
    if (event.momentumPhase != NSEventPhaseNone) return gesture.consumed && gesture.window == window ? nil : event;
    BOOL began = (event.phase & NSEventPhaseBegan) != 0;
    if (gesture.window != window || began || (!gesture.active && event.timestamp-gesture.last>.35)) {
        if (gesture.pending.count) DPLibraryPassPending(gesture);
        [gesture resetForWindow:window];
    }
    if (gesture.nativePass) return event;
    DPLibraryController *current=gesture.active ? gesture.controller : DPLibraryForWindow(window);
    NSView *header = current.expanded ? nil : DPFindView(window.contentView,^BOOL(NSView *v) { return DPIsKind(v,DPDiaSidebarHeader) && !v.hiddenOrHasHiddenAncestor; });
    NSView *host = current.expanded ? current.sidebarHost : header.superview;
    if (!host || (!gesture.active && !NSPointInRect([host convertPoint:event.locationInWindow fromView:nil],host.bounds))) {
        if (gesture.pending.count) DPLibraryPassPending(gesture);
        return event;
    }
    BOOL showing = current.expanded;
    BOOL eligible = showing || DPLibraryAtFirstSpace(window);
    if (event.type == NSEventTypeSwipe) {
        if (gesture.consumed) return nil;
        if ((showing && event.deltaX<0) || (!showing && event.deltaX>0 && eligible)) { DPLibraryToggle(window); return nil; }
        return event;
    }
    if (!eligible && !gesture.active) { if (gesture.pending.count) DPLibraryPassPending(gesture); return event; }
    [gesture recordX:event.scrollingDeltaX y:event.scrollingDeltaY time:event.timestamp];
    BOOL ended = (event.phase & (NSEventPhaseEnded | NSEventPhaseCancelled)) != 0;
    if (!gesture.active && !gesture.consumed) {
        BOOL vertical = fabs(gesture.y)>2 && fabs(gesture.y)>fabs(gesture.x)*1.2;
        BOOL nextSpace = !showing && gesture.x < -4;
        if (vertical || nextSpace || ended) { DPLibraryPassPending(gesture); return event; }
        if (fabs(gesture.x)>5 && fabs(gesture.x)>fabs(gesture.y)*1.6) {
            if ([gesture begin]) [gesture.pending removeAllObjects];
        }
        if (!gesture.active) {
            [gesture.pending addObject:event];
            if (event.phase == NSEventPhaseNone) {
                NSUInteger generation = ++gesture.generation;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,180*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ if (generation == gesture.generation) DPLibraryPassPending(gesture); });
            }
            return nil;
        }
    }
    if (!gesture.active) return gesture.consumed ? nil : event;
    [gesture apply];
    if (ended) [gesture finishCancelled:(event.phase & NSEventPhaseCancelled) != 0];
    else if (event.phase == NSEventPhaseNone) {
        NSUInteger generation = ++gesture.generation;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,180*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ if (generation == gesture.generation) [gesture finishCancelled:NO]; });
    }
    return nil;
}
