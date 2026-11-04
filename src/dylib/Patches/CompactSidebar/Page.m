#import "CompactSidebar.h"

static NSHashTable<NSView *> *DPPanes;
static char DPPaneFrameKey, DPItemFrameKey, DPBarPlaceKey;

// The pane at the window's left starts where the strip ends. Its own left edge only ever moves right, to that point, so
// laying it out again changes nothing.
static NSRect DPPaneFrame(NSView *pane, NSRect frame) {
    NSView *superview = pane.superview;
    if (!superview || DPStripVisible(pane.window) == 0) return frame;
    CGFloat edge = [superview convertPoint:NSMakePoint(DPStripRight(pane.window), 0) fromView:nil].x;
    if (NSMinX(frame) >= edge) return frame;
    frame.size.width = MAX(0, NSMaxX(frame) - edge);
    frame.origin.x = edge;
    return frame;
}

static void DPPane_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSRect dia = [DPDiaValue(self, &DPPaneFrameKey, @(frame)) rectValue], ours = DPPaneFrame(self, dia);
    [DPPanes addObject:self];
    DPOverride(self, &DPPaneFrameKey, @(dia), @(ours));
    DPCallOriginal(DPPane_setFrame, self, ours);
}

// The toolbar's buttons left of the address field move right of the window buttons, and the field gives up the room.
static void DPClearLights(NSView *bar) {
    NSView *field = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); }), *items = field.superview;
    if (!field) return;
    CGFloat lights = DPStripPresent(bar.window) ? DPLightsRight(bar.window) : 0;
    CGFloat edge = lights > 0 ? [items convertPoint:NSMakePoint(lights + DPLightsClearance, 0) fromView:nil].x : -CGFLOAT_MAX;
    NSRect fieldFrame = [DPDiaValue(field, &DPItemFrameKey, @(field.frame)) rectValue];
    NSMutableArray<NSView *> *leading = [NSMutableArray new];
    CGFloat first = NSMinX(fieldFrame);
    for (NSView *item in items.subviews) {
        NSRect laidOut = [DPDiaValue(item, &DPItemFrameKey, @(item.frame)) rectValue];
        if (item == field || item.hidden || NSMaxX(laidOut) > NSMinX(fieldFrame) + 0.5) continue;
        [leading addObject:item];
        first = MIN(first, NSMinX(laidOut));
    }
    CGFloat shift = MAX(0, edge - first);
    for (NSView *item in [leading arrayByAddingObject:field]) {
        NSRect laidOut = [DPDiaValue(item, &DPItemFrameKey, @(item.frame)) rectValue], frame = laidOut;
        frame.origin.x += shift;
        if (item == field) frame.size.width = MAX(0, NSWidth(frame) - shift);
        DPOverride(item, &DPItemFrameKey, @(laidOut), @(frame));
        if (!NSEqualRects(item.frame, frame)) item.frame = frame;
    }
}

void DPClearLightsIn(NSWindow *window) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) if (bar.window == window) DPClearLights(bar);
}

static void DPBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPBar_layout, self);
    DPClearLights(self);
    DPLayoutStrip(DPHostIn(self.window));  // The strip takes the toolbar's color, which follows the theme.
    // The sidebar's window buttons line up with the toolbar, and its tabs with the page under it, so they're placed
    // again when the toolbar moves up or down; only then, or the two would keep laying each other out.
    NSRect place = [self convertRect:self.bounds toView:nil];
    NSValue *was = DPGet(self, &DPBarPlaceKey);
    if (was && fabs(NSMinY(was.rectValue) - NSMinY(place)) < 0.25 && fabs(NSHeight(was.rectValue) - NSHeight(place)) < 0.25) return;
    DPSet(self, &DPBarPlaceKey, @(place));
    NSView *root = DPSidebarRootIn(self.window);
    DPSubview(root, DPDiaSidebarHeader).needsLayout = YES;
    root.needsLayout = YES;  // Its controller lines the tabs up after.
}

void DPRelayoutCompactPanes(NSWindow *window) {
    for (NSView *pane in DPPanes)
        if (pane.window == window) pane.frame = [DPDiaValue(pane, &DPPaneFrameKey, @(pane.frame)) rectValue];
}

// Dia slides the card into place, and edge-to-edge moves it again; each page starts where the strip ends once it stops.
static void DPCard_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPCallOriginal(DPCard_setFrame, self, frame);
    if (!DPStripShown(self.window)) return;
    for (NSView *pane in DPPanes) {
        if (![pane isDescendantOf:self]) continue;
        NSRect dia = [DPDiaValue(pane, &DPPaneFrameKey, @(pane.frame)) rectValue];
        if (!NSEqualRects(DPPaneFrame(pane, dia), pane.frame)) pane.frame = dia;  // Through its setFrame:, which places it.
    }
}

void DPInstallCompactPage(void) {
    DPPanes = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaContentContainer, @selector(setFrame:), (IMP)DPCard_setFrame);
    DPHook(DPDiaContentPane, @selector(setFrame:), (IMP)DPPane_setFrame);
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPBar_layout);
}
