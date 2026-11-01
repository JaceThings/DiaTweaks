#import "StdPatch/StdPatch.h"

// Dia shows the address field's background and its buttons only while the field's hover tracker finds the pointer over
// it, which it decides by hit-testing the window at the pointer, and only once the pointer has moved there: a hover that
// starts without a move doesn't count. While one of the field's trackers decides, the window reports the pointer at the
// field's centre, and for a moment after, when the field checks the pointer again before it shows as hovered. So the field
// reads as hovered wherever the pointer is.

extern DPPatch DPShowAddressField;

static NSView *DPDecidingField, *DPHeldField;
static CFTimeInterval DPHeldUntil;

static NSView *DPTrackedView(id tracker) { return objc_loadWeak((__autoreleasing id *)DPIvar(tracker, "view")); }
// The field's own tracker that waits for the pointer to move before the field shows as hovered.
static BOOL DPShowsHover(NSView *field) {
    id delayed = (__bridge id)*(void **)DPIvar(field, "hoverTracker");
    return delayed && *(BOOL *)DPIvar(delayed, "isHoverActive");
}

static NSPoint DPFieldCentre(NSView *field) { return [field convertPoint:NSMakePoint(NSMidX(field.bounds), NSMidY(field.bounds)) toView:nil]; }

static NSPoint DPWindow_mouseLocation(NSWindow *self, SEL _cmd) {
    NSView *field = DPDecidingField ?: CACurrentMediaTime() < DPHeldUntil ? DPHeldField : nil;
    return field.window == self ? DPFieldCentre(field) : DPCallOriginal(DPWindow_mouseLocation, self);
}

static void DPDecide(id tracker, void (^decide)(void)) {
    NSView *view = DPTrackedView(tracker);
    DPDecidingField = DPShowAddressField.on && DPIsKind(view, DPDiaAddressField) ? view : nil;
    decide();
    if (DPDecidingField) DPHeldField = DPDecidingField, DPHeldUntil = CACurrentMediaTime() + 0.25;
    DPDecidingField = nil;
}

static void DPTracker_mouseEntered(id self, SEL _cmd, NSEvent *event) { DPDecide(self, ^{ DPCallOriginal(DPTracker_mouseEntered, self, event); }); }
static void DPTracker_mouseMoved(id self, SEL _cmd, NSEvent *event) { DPDecide(self, ^{ DPCallOriginal(DPTracker_mouseMoved, self, event); }); }
static void DPTracker_mouseExited(id self, SEL _cmd, NSEvent *event) { DPDecide(self, ^{ DPCallOriginal(DPTracker_mouseExited, self, event); }); }

static NSTrackingArea *DPHoverArea(NSView *field) {
    for (NSTrackingArea *area in field.trackingAreas)
        if (DPIsKind(area.owner, DPDiaHoverTracker)) return area;
    return nil;
}

// Has the field's tracker decide again, as the pointer moving in or leaving would.
static void DPRedecide(NSView *field, BOOL entering) {
    NSTrackingArea *area = DPHoverArea(field);
    if (!area || !field.window) return;
    NSPoint location = field.window.mouseLocationOutsideOfEventStream;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSEvent *event = [NSEvent enterExitEventWithType:entering ? NSEventTypeMouseEntered : NSEventTypeMouseExited location:location modifierFlags:0
                                            timestamp:now windowNumber:field.window.windowNumber context:nil eventNumber:0
                                       trackingNumber:(NSInteger)area userData:NULL];
    if (!entering) return [area.owner mouseExited:event];
    [area.owner mouseEntered:event];
    [area.owner mouseMoved:[NSEvent mouseEventWithType:NSEventTypeMouseMoved location:location modifierFlags:0 timestamp:now
                                          windowNumber:field.window.windowNumber context:nil eventNumber:0 clickCount:0 pressure:0]];
}

// New windows and fields, and a hidden toolbar coming back, lay the field out before the pointer gets near it.
static void DPField_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPField_layout, self);
    if (DPShowAddressField.on && !DPShowsHover(self)) DPRedecide(self, YES);
}

static void DPApplyShowAddressField(DPPatch *patch) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) DPRedecide(field, patch->on);
}

static NSString *DPVerifyShowAddressField(DPPatch *patch) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) {
        NSTrackingArea *area = DPHoverArea(field);
        // A hidden toolbar takes no hits, so the field can't read as hovered until it shows.
        if (!area || field.hiddenOrHasHiddenAncestor || ![[field.window.contentView hitTest:DPFieldCentre(field)] isDescendantOf:field]) continue;
        NSView *underPointer = [field.window.contentView hitTest:field.window.mouseLocationOutsideOfEventStream];
        if (patch->on && !DPShowsHover(field)) return @"address field hides its background and buttons";
        if (!patch->on && DPShowsHover(field) && ![underPointer isDescendantOf:field]) return @"address field stays highlighted";
    }
    return nil;
}

static void DPInstallShowAddressField(void) {
    DPHookClass(NSWindow.class, @selector(mouseLocationOutsideOfEventStream), (IMP)DPWindow_mouseLocation);
    DPHook(DPDiaHoverTracker, @selector(mouseEntered:), (IMP)DPTracker_mouseEntered);
    DPHook(DPDiaHoverTracker, @selector(mouseMoved:), (IMP)DPTracker_mouseMoved);
    DPHook(DPDiaHoverTracker, @selector(mouseExited:), (IMP)DPTracker_mouseExited);
    DPHook(DPDiaAddressField, @selector(layout), (IMP)DPField_layout);
}

DP_PATCH(DPShowAddressField) {
    .key = @"showAddressField",
    .order = 55,
    .title = @"Always show address field",
    .detail = @"Keep the address field’s background and its bookmark, split view and site buttons showing without pointing at it.",
    .symbol = @"link",
    .tint = @"systemBlueColor",
    .section = @"Toolbar",
    .classes = DPClasses(DPDiaAddressField, DPDiaHoverTracker),
    .install = DPInstallShowAddressField,
    .apply = DPApplyShowAddressField,
    .verify = DPVerifyShowAddressField,
};
