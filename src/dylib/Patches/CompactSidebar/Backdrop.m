#import "CompactSidebar.h"

// While the command bar is open, Dia blurs the page behind it with a backdrop inside the page's card. The strip sits over
// the card, out of its reach. So while the strip shows, one blur like Dia's covers the strip and the page together, under
// the command bar, in place of Dia's: two would meet in a seam at the strip's edge.
static char DPBlurKey, DPDiaBlurKey;

static Class DPBackdropClass(void) { return NSClassFromString(@"CABackdropLayer"); }

static CALayer *DPBackdropIn(NSView *view) {
    for (CALayer *layer in view.layer.sublayers) if ([layer isKindOfClass:DPBackdropClass()]) return layer;
    return nil;
}

// Dia's blur: a plain view, inside the card, that holds a backdrop layer.
static NSView *DPPageBlurIn(NSView *card) {
    for (NSView *inner in card.subviews)
        for (NSView *view in inner.subviews)
            if (DPBackdropIn(view)) return view;
    return nil;
}

static void DPMatchBlur(NSWindow *window) {
    NSView *host = DPHostIn(window), *space = host.superview, *card = DPSubview(space, DPDiaContentContainer);
    if (!card) return;
    NSView *blur = DPGet(space, &DPBlurKey), *dia = DPPageBlurIn(card), *hid = DPGet(space, &DPDiaBlurKey);
    BOOL show = dia && DPStripPresent(window);
    if (hid && hid != dia) hid.hidden = NO;
    if (!show) {
        blur.hidden = YES;
        if (dia) dia.hidden = NO;
        DPSet(space, &DPDiaBlurKey, nil);
        return;
    }
    if (!blur) {
        DPSet(space, &DPBlurKey, blur = [NSView new]);
        blur.wantsLayer = YES;
        blur.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    // Over the strip and the card, under the command bar Dia adds after them.
    NSView *above = [space.subviews indexOfObject:host] > [space.subviews indexOfObject:card] ? host : card;
    if (blur.superview != space || [space.subviews indexOfObject:blur] != [space.subviews indexOfObject:above] + 1)
        [space addSubview:blur positioned:NSWindowAbove relativeTo:above];
    CALayer *diaLayer = DPBackdropIn(dia);
    DPNow(^{
        CALayer *layer = DPBackdropIn(blur);
        if (!layer) [blur.layer addSublayer:layer = [[DPBackdropClass() alloc] initWithLayer:diaLayer]];
        layer.filters = diaLayer.filters;
        layer.backgroundColor = diaLayer.backgroundColor;
        blur.frame = space.bounds;
        layer.frame = blur.bounds;
        blur.hidden = NO;
        dia.hidden = YES;
    });
    DPSet(space, &DPDiaBlurKey, dia);
}

// Dia adds its blur as the command bar opens and takes it away as it closes; the strip's follows once Dia is done.
static void DPInner_didAddSubview(NSView *self, SEL _cmd, NSView *sub) {
    DPCallOriginal(DPInner_didAddSubview, self, sub);
    if (!DPIsKind(self.superview, DPDiaContentContainer) || !DPCompactSidebar.on) return;
    __weak NSWindow *window = self.window;
    dispatch_async(dispatch_get_main_queue(), ^{ DPMatchBlur(window); });
}

static void DPInner_willRemoveSubview(NSView *self, SEL _cmd, NSView *sub) {
    DPCallOriginal(DPInner_willRemoveSubview, self, sub);
    if (!DPIsKind(self.superview, DPDiaContentContainer) || !DPBackdropIn(sub)) return;
    NSView *space = self.superview.superview;
    ((NSView *)DPGet(space, &DPBlurKey)).hidden = YES;
    sub.hidden = NO;
    DPSet(space, &DPDiaBlurKey, nil);
}

void DPInstallCompactBackdrop(void) {
    DPHook(DPDiaFlippedView, @selector(didAddSubview:), (IMP)DPInner_didAddSubview);
    DPHook(DPDiaFlippedView, @selector(willRemoveSubview:), (IMP)DPInner_willRemoveSubview);
}
