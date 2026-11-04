#import "CompactSidebar.h"

static char DPLightsKey, DPPrioritiesKey;

// The window buttons sit over the toolbar, so they hide and show with it as hide toolbar fades it.
CGFloat DPToolbarAlpha(NSWindow *window) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) if (bar.window == window && !bar.hiddenOrHasHiddenAncestor) return bar.alphaValue;
    return 1;
}

static NSView *DPLightsIn(NSView *root) {
    NSView *header = root ? DPSubview(root, DPDiaSidebarHeader) : nil;
    return header ? DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaTrafficLights); }) : nil;
}

CGFloat DPLightsRight(NSWindow *window) {
    NSView *lights = DPLightsIn(DPSidebarRootIn(window));
    if (!lights || lights.hiddenOrHasHiddenAncestor) return 0;
    return NSMaxX([lights convertRect:lights.bounds toView:nil]);
}

CGFloat DPLightsLeft(NSWindow *window) {
    NSView *lights = DPLightsIn(DPSidebarRootIn(window));
    if (!lights || lights.hiddenOrHasHiddenAncestor) return 0;
    return NSMinX([lights convertRect:lights.bounds toView:nil]);
}

static NSView *DPHostOf(NSView *header) { return DPHostIn(header.window) ?: header.superview; }

// Where the middle of the toolbar's buttons is once the toolbar is in place, from the window's bottom: the card's top
// less the buttons' fixed depth in it. Hide toolbar moves the toolbar meanwhile, which the window buttons don't follow.
static CGFloat DPToolbarButtonsMiddle(NSWindow *window) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) {
        if (bar.window != window || bar.hiddenOrHasHiddenAncestor) continue;
        NSView *field = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); }), *button = nil;
        for (NSView *item in field.superview.subviews)
            if (!item.hidden && NSWidth(item.frame) > 0 && item != field) { button = item; break; }
        NSView *card = bar;
        while (card && !DPIsKind(card, DPDiaContentContainer)) card = card.superview;
        if (!button || !card) return NAN;
        NSRect inBar = [button convertRect:button.bounds toView:bar];
        CGFloat depth = bar.isFlipped ? NSMidY(inBar) : NSHeight(bar.bounds) - NSMidY(inBar);
        return NSMaxY([card convertRect:card.bounds toView:nil]) - depth;
    }
    return NAN;
}

// In the strip, the header is as narrow as the strip. Dia's row of window buttons would squeeze them to fit; instead it
// lets them run past its edge, over the toolbar. They also line up with the toolbar's buttons there.
static void DPPlaceLights(NSView *header, BOOL strip) {
    NSView *lights = DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaTrafficLights); });
    NSStackView *row = (NSStackView *)lights.superview;
    if (![row isKindOfClass:NSStackView.class]) return;
    NSArray<NSNumber *> *dia = DPGet(row, &DPPrioritiesKey);
    if (strip && !dia) {
        DPSet(row, &DPPrioritiesKey, @[ @([row clippingResistancePriorityForOrientation:NSLayoutConstraintOrientationHorizontal]),
                                       @([lights contentCompressionResistancePriorityForOrientation:NSLayoutConstraintOrientationHorizontal]) ]);
        [row setClippingResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [lights setContentCompressionResistancePriority:NSLayoutPriorityRequired - 1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        row.clipsToBounds = NO;
    } else if (!strip && dia) {
        DPSet(row, &DPPrioritiesKey, nil);
        [row setClippingResistancePriority:dia[0].floatValue forOrientation:NSLayoutConstraintOrientationHorizontal];
        [lights setContentCompressionResistancePriority:dia[1].floatValue forOrientation:NSLayoutConstraintOrientationHorizontal];
    }
    lights.alphaValue = strip ? DPToolbarAlpha(header.window) : 1;  // Its setter adds the reveal.
    if (!strip || lights.hiddenOrHasHiddenAncestor) {  // Hide Window Controls hides them.
        if (row.bounds.origin.y != 0) [row setBoundsOrigin:NSZeroPoint];
        return;
    }
    NSView *close = [header.window standardWindowButton:NSWindowCloseButton];
    CGFloat want = DPToolbarButtonsMiddle(header.window);
    if (isnan(want) || ![close isDescendantOf:lights] || close.hiddenOrHasHiddenAncestor) return;
    CGFloat have = NSMidY([close convertRect:close.bounds toView:nil]);
    if (fabs(want - have) < 0.25) return;
    // Through the row's bounds: constraints place its frame, and moving that would lay the header out again and again.
    CGFloat shift = want - have;
    [row setBoundsOrigin:NSMakePoint(0, row.bounds.origin.y + (row.isFlipped ? shift : -shift))];
}

static void DPHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_layout, self);
    DPPlaceLights(self, DPStripPresent(self.window) && !DPStripExpanded(DPHostOf(self)));
    // Other tweaks move the window buttons as the header lays out; the toolbar's buttons follow them.
    NSNumber *lights = @(DPLightsRight(self.window));
    if (![DPGet(self, &DPLightsKey) isEqual:lights]) {
        DPSet(self, &DPLightsKey, lights);
        DPClearLightsIn(self.window);
    }
    NSView *host = DPHostOf(self);
    CGFloat alpha = DPStripPresent(self.window) && !DPStripExpanded(host) ? 0 : 1;
    NSView *profile = DPFindView(self, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaProfileIndicator); });
    if (profile.alphaValue != alpha) profile.alphaValue = alpha;
}

// Over the toolbar, the window buttons take clicks and the toolbar gets the rest, until the sidebar opens over it. The
// buttons reach past the strip, where the strip alone wouldn't pass clicks to them.
static NSView *DPStripHitTest(NSView *self, NSPoint point, NSView *(^original)(void)) {
    if (!DPStripOn(self) || DPStripExpanded(self)) return original();
    NSView *root = DPSidebarRootIn(self.window), *header = root ? DPSubview(root, DPDiaSidebarHeader) : nil, *lights = DPLightsIn(root);
    if (lights && !lights.hiddenOrHasHiddenAncestor && lights.alphaValue > 0.01 && NSPointInRect([lights convertPoint:point fromView:self.superview], lights.bounds))
        return [lights hitTest:[lights.superview convertPoint:point fromView:self.superview]];
    // With the toolbar hidden, the tabs rise into the header's space, where they take clicks.
    NSView *list = DPListIn(self.window);
    NSPoint inRoot = [root convertPoint:point fromView:self.superview];
    if (list && NSPointInRect(inRoot, list.frame)) return [list hitTest:inRoot];
    NSPoint local = [header convertPoint:point fromView:self.superview];
    if (header && local.y >= 0 && local.y < NSHeight(header.bounds)) return nil;
    NSView *hit = original();
    return DPIsKind(hit, DPDiaSidebarResizer) ? nil : hit;  // The strip can't be dragged wider.
}

static NSView *DPFloat_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    return DPStripHitTest(self, point, ^NSView *{ return DPCallOriginal(DPFloat_hitTest, self, point); });
}

static NSView *DPRoot_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    return DPStripHitTest(self, point, ^NSView *{ return DPCallOriginal(DPRoot_hitTest, self, point); });
}

static void DPBar_setAlphaValue(NSView *self, SEL _cmd, CGFloat alpha) {
    DPCallOriginal(DPBar_setAlphaValue, self, alpha);
    NSView *lights = DPLightsIn(DPSidebarRootIn(self.window));
    if (lights && DPStripPresent(self.window)) lights.alphaValue = alpha;  // Its setter adds the reveal.
    DPPlaceListIn(self.window);
    DPSettleReveal(self.window);
}

// Hide Window Controls takes the buttons out of the header's row, which puts them back as it lays out, after the header
// has; the toolbar's buttons follow them either way.
static void DPLights_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPLights_viewDidMoveToWindow, self);
    if (DPStripShown(self.window)) DPClearLightsIn(self.window);
}

void DPInstallCompactHeader(void) {
    DPHook(DPDiaTrafficLights, @selector(viewDidMoveToWindow), (IMP)DPLights_viewDidMoveToWindow);
    DPHook(DPDiaToolbar, @selector(setAlphaValue:), (IMP)DPBar_setAlphaValue);
    DPHook(DPDiaSidebarHeader, @selector(layout), (IMP)DPHeader_layout);
    DPHook(DPDiaFloatingSidebar, @selector(hitTest:), (IMP)DPFloat_hitTest);
    DPHook(DPDiaSidebarRoot, @selector(hitTest:), (IMP)DPRoot_hitTest);
}
