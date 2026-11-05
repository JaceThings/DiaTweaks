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

static BOOL DPPlacingPane;  // Set while the strip places a pane, which isn't Dia asking for a frame.

static NSRect DPDiaPaneFrame(NSView *pane) {
    NSValue *dia = DPGet(pane, &DPPaneFrameKey);
    return dia ? dia.rectValue : pane.frame;
}

static void DPPlacePane(NSView *pane) {
    NSRect frame = DPPaneFrame(pane, DPDiaPaneFrame(pane));
    if (NSEqualRects(pane.frame, frame)) return;
    DPPlacingPane = YES;
    pane.frame = frame;
    DPPlacingPane = NO;
}

// Dia moves the page with setFrame:, setFrameOrigin: and setFrameSize:, as when a site shows a photo; each records
// what Dia asked for, and the pane is placed from that.
static void DPPaneAsked(NSView *pane, NSRect frame) {
    [DPPanes addObject:pane];
    DPSet(pane, &DPPaneFrameKey, @(frame));
    DPPlacePane(pane);
}

static void DPPane_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    if (DPPlacingPane) return DPCallOriginal(DPPane_setFrame, self, frame);
    DPPaneAsked(self, frame);
}

static void DPPane_setFrameOrigin(NSView *self, SEL _cmd, NSPoint origin) {
    if (DPPlacingPane) return DPCallOriginal(DPPane_setFrameOrigin, self, origin);
    DPPaneAsked(self, (NSRect){origin, DPDiaPaneFrame(self).size});
}

static void DPPane_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    if (DPPlacingPane) return DPCallOriginal(DPPane_setFrameSize, self, size);
    DPPaneAsked(self, (NSRect){DPDiaPaneFrame(self).origin, size});
}

// The toolbar's buttons left of the address field move right of the window buttons, and the field gives up the room.
// After the downloads button, they keep their own spacing from it, as if it were the first of them.
static void DPClearLights(NSView *bar) {
    NSView *field = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); }), *items = field.superview;
    if (!field) return;
    NSRect fieldFrame = [DPDiaValue(field, &DPItemFrameKey, @(field.frame)) rectValue];
    NSMutableArray<NSView *> *leading = [NSMutableArray new];
    for (NSView *item in items.subviews) {
        if (item == field || item.hidden || DPIsDownloadsHover(item)) continue;
        NSRect laidOut = [DPDiaValue(item, &DPItemFrameKey, @(item.frame)) rectValue];
        if (NSMaxX(laidOut) > NSMinX(fieldFrame) + 0.5) continue;
        [leading addObject:item];
    }
    NSRect (^laid)(NSView *) = ^NSRect(NSView *item) { return [DPDiaValue(item, &DPItemFrameKey, @(item.frame)) rectValue]; };
    [leading sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) { return [@(NSMinX(laid(a))) compare:@(NSMinX(laid(b)))]; }];
    CGFloat first = leading.count ? NSMinX(laid(leading[0])) : NSMinX(fieldFrame);
    BOOL present = DPStripPresent(bar.window);
    CGFloat lights = present ? DPLightsRight(bar.window) : 0, downloads = present ? DPDownloadsMid(bar.window) : NAN, edge = -CGFLOAT_MAX;
    if (!isnan(downloads) && leading.count) {
        NSRect one = laid(leading[0]);
        CGFloat pitch = leading.count > 1 ? NSMidX(laid(leading[1])) - NSMidX(one) : NSWidth(one) + 5;
        edge = [items convertPoint:NSMakePoint(downloads, 0) fromView:nil].x + pitch - NSWidth(one) / 2;
    } else if (lights > 0) edge = [items convertPoint:NSMakePoint(lights + DPLightsClearance, 0) fromView:nil].x;
    CGFloat shift = MAX(0, edge - first);
    for (NSView *item in [leading arrayByAddingObject:field]) {
        NSRect laidOut = [DPDiaValue(item, &DPItemFrameKey, @(item.frame)) rectValue], frame = laidOut;
        frame.origin.x += shift;
        if (item == field) frame.size.width = MAX(0, NSWidth(frame) - shift);
        DPOverride(item, &DPItemFrameKey, @(laidOut), @(frame));
        if (!NSEqualRects(item.frame, frame)) item.frame = frame;
    }
    DPPlaceDownloadsHover(bar);
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
        if (pane.window == window) DPPlacePane(pane);
}

// Dia slides the card into place, and edge-to-edge moves it again; each page starts where the strip ends once it stops.
static void DPCard_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPCallOriginal(DPCard_setFrame, self, frame);
    if (!DPStripShown(self.window)) return;
    for (NSView *pane in DPPanes) if ([pane isDescendantOf:self]) DPPlacePane(pane);
}

void DPInstallCompactPage(void) {
    DPPanes = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaContentContainer, @selector(setFrame:), (IMP)DPCard_setFrame);
    DPHook(DPDiaContentPane, @selector(setFrame:), (IMP)DPPane_setFrame);
    DPHook(DPDiaContentPane, @selector(setFrameOrigin:), (IMP)DPPane_setFrameOrigin);
    DPHook(DPDiaContentPane, @selector(setFrameSize:), (IMP)DPPane_setFrameSize);
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPBar_layout);
}
