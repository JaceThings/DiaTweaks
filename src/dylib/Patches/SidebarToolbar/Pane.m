#import "SidebarToolbar.h"

static char DPShiftKey, DPFillsKey;

static CGFloat DPPaneTop(NSView *pane, NSRect r) { return pane.isFlipped ? NSMinY(r) : NSHeight(pane.bounds) - NSMaxY(r); }
static CGFloat DPPaneBottom(NSView *pane, NSRect r) { return pane.isFlipped ? NSMaxY(r) : NSHeight(pane.bounds) - NSMinY(r); }

static NSRect DPUnshifted(NSView *view) {
    return [DPDiaValue(view, &DPShiftKey, @(view.frame)) rectValue];
}

// Dia sizes the web view once instead of autoresizing it.
static void DPFillWithChildren(NSView *view, NSSize laidOut) {
    for (NSView *child in view.subviews) {
        if (!DPGet(child, &DPFillsKey)) {
            if (!NSEqualRects(child.frame, (NSRect){NSZeroPoint, laidOut})) continue;
            DPSet(child, &DPFillsKey, @YES);
        }
        child.frame = view.bounds;
    }
}

// Puts back what DPShiftPane moved, before the hidden toolbar lays the pane out from Dia's frames.
void DPRestorePane(NSView *pane) {
    for (NSView *view in pane.subviews) {
        NSArray *values = DPGet(view, &DPShiftKey);
        if (!values) continue;
        DPSet(view, &DPShiftKey, nil);
        if (![values[1] isEqual:@(view.frame)]) continue;
        view.frame = [values[0] rectValue];
        DPFillWithChildren(view, view.frame.size);
    }
}

// With its bar in the sidebar, everything stacked under the bar moves up into its place.
static void DPShiftPane(NSView *pane) {
    NSView *bar = DPPaneBar(pane);
    if (!bar || bar.superview == pane) return DPRestorePane(pane);
    NSRect barFrame = DPPaneFrame(bar);
    CGFloat shift = NSHeight(barFrame), edge = DPPaneBottom(pane, barFrame);
    NSMutableArray<NSView *> *stack = pane.subviews.mutableCopy;
    [stack sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        return [@(DPPaneTop(pane, DPUnshifted(a))) compare:@(DPPaneTop(pane, DPUnshifted(b)))];
    }];
    for (NSView *view in stack) {
        NSRect laidOut = DPUnshifted(view);
        if (fabs(DPPaneTop(pane, laidOut) - edge) > 0.5) continue;
        BOOL reachesBottom = fabs(DPPaneBottom(pane, laidOut) - NSHeight(pane.bounds)) < 0.5;
        if (!reachesBottom) edge = DPPaneBottom(pane, laidOut);
        NSRect frame = laidOut;
        if (reachesBottom) frame.size.height += shift;
        if (pane.isFlipped) frame.origin.y -= shift;
        else if (!reachesBottom) frame.origin.y += shift;
        DPOverride(view, &DPShiftKey, @(laidOut), @(frame));
        view.frame = frame;
        DPFillWithChildren(view, laidOut.size);
    }
}

static void DPPane_layout(NSView *self, SEL _cmd) {
    NSView *bar = DPPaneBar(self);
    if (!bar || bar.superview == self) DPRestorePane(self);
    DPCallOriginal(DPPane_layout, self);
    [DPDockPanes addObject:self];
    DPUpdateDock(self.window);
    DPShiftPane(self);
}

void DPInstallPane(void) {
    DPHook(DPDiaContentPane, @selector(layout), (IMP)DPPane_layout);
}
