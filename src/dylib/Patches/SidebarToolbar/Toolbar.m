#import "SidebarToolbar.h"

static char DPRequestedFrameKey, DPAppearanceKey;

NSRect DPPaneFrame(NSView *bar) {
    NSValue *requested = DPGet(bar, &DPRequestedFrameKey);
    return requested ? requested.rectValue : bar.frame;
}

static void DPToolbar_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPSet(self, &DPRequestedFrameKey, @(frame));
    DPSetBarFrame(self, DPIsDocked(self) ? DPDockFrame(self.superview, self) : frame);
}

void DPSetBarFrame(NSView *bar, NSRect frame) {
    if (NSEqualRects(bar.frame, frame)) return;
    SEL sel = @selector(setFrame:);
    ((void (*)(id, SEL, NSRect))DPOriginalIMP(bar, sel, (IMP)DPToolbar_setFrame))(bar, sel, frame);
}

// Dia matches the bar to the page; in the sidebar it matches the app.
static void DPToolbar_setAppearance(NSView *self, SEL _cmd, NSAppearance *appearance) {
    DPSet(self, &DPAppearanceKey, appearance);
    DPCallOriginal(DPToolbar_setAppearance, self, DPIsDocked(self) ? nil : appearance);
}

void DPApplyBarAppearance(NSView *bar) {
    SEL sel = @selector(setAppearance:);
    NSAppearance *appearance = DPIsDocked(bar) ? nil : DPGet(bar, &DPAppearanceKey);
    ((void (*)(id, SEL, NSAppearance *))DPOriginalIMP(bar, sel, (IMP)DPToolbar_setAppearance))(bar, sel, appearance);
}

// Docked, it overlaps the sidebar header, so clicks between its controls reach the header.
static NSView *DPToolbar_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    NSView *hit = DPCallOriginal(DPToolbar_hitTest, self, point);
    for (NSView *v = hit; v && v != self; v = v.superview) if (DPIsFaded(v)) return nil;
    if (!DPIsDocked(self)) return hit;
    if (hit == self || DPIsKind(hit, DPDiaTouchTransparent)) return nil;
    // Docked, the address text isn't selectable, and the text view opens the command bar from a click anywhere
    // on the address but its buttons.
    NSView *address = DPBarAddress(self);
    if (![hit isDescendantOf:address]) return hit;
    for (NSView *v = hit; v != address; v = v.superview) if ([v isKindOfClass:NSControl.class]) return hit;
    return DPBarText(self) ?: hit;
}

// The bar drags the window from a click on itself, and AppKit hands it the clicks its hitTest: passes on, the traffic
// lights' among them, so those go on to whatever is under the bar.
static NSView *DPUnderToolbar(NSView *bar, NSEvent *event) {
    NSView *frame = bar.window.contentView.superview;
    NSView *hit = DPIsDocked(bar) ? [frame hitTest:[frame convertPoint:event.locationInWindow fromView:nil]] : nil;
    return hit && ![hit isDescendantOf:bar] ? hit : nil;
}

static void DPToolbar_mouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    NSView *under = DPUnderToolbar(self, event);
    if (under) [under mouseDown:event];
    else DPCallOriginal(DPToolbar_mouseDown, self, event);
}

static void DPToolbar_mouseUp(NSView *self, SEL _cmd, NSEvent *event) {
    NSView *under = DPUnderToolbar(self, event);
    if (under) [under mouseUp:event];
    else DPCallOriginal(DPToolbar_mouseUp, self, event);
}

static void DPToolbar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPToolbar_layout, self);
    [DPDockBars addObject:self];
    DPArrangeBar(self);
}

// Dia selects the address text from its own gestures, whatever `selectable` says.
static void DPAddressText_setSelectedRanges(NSTextView *self, SEL _cmd, NSArray<NSValue *> *ranges, NSSelectionAffinity affinity, BOOL stillSelecting) {
    if (DPIsDocked(DPToolbarOf(self))) ranges = @[[NSValue valueWithRange:NSMakeRange(0, 0)]];
    DPCallOriginal(DPAddressText_setSelectedRanges, self, ranges, affinity, stillSelecting);
}

void DPInstallToolbar(void) {
    DPHook(DPDiaToolbar, @selector(setFrame:), (IMP)DPToolbar_setFrame);
    DPHook(DPDiaToolbar, @selector(setAppearance:), (IMP)DPToolbar_setAppearance);
    DPHook(DPDiaToolbar, @selector(hitTest:), (IMP)DPToolbar_hitTest);
    DPHook(DPDiaToolbar, @selector(mouseDown:), (IMP)DPToolbar_mouseDown);
    DPHook(DPDiaToolbar, @selector(mouseUp:), (IMP)DPToolbar_mouseUp);
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPToolbar_layout);
    DPHook(DPDiaAddressText, @selector(setSelectedRanges:affinity:stillSelecting:), (IMP)DPAddressText_setSelectedRanges);
}
