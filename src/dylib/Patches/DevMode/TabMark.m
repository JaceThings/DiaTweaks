#import "DevMode.h"

static const CGFloat DPOutlineWidth = 1.5, DPDash = 6.5;
static char DPMarkKey;

static NSView *DPShapeIn(NSView *tab) { return DPFindView(tab, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTabShape); }); }

// The selected tab's fill is clipped to Dia's own tab shape.
static NSView *DPFillIn(NSView *shape) {
    for (NSView *view in shape.subviews) {
        CAShapeLayer *mask = (CAShapeLayer *)view.layer.mask;
        if ([mask isKindOfClass:CAShapeLayer.class] && mask.path && !DPIsKind(view, "DPTabMark")) return view;
    }
    return nil;
}

static CGPathRef DPShapePath(NSView *shape) { return ((CAShapeLayer *)DPFillIn(shape).layer.mask).path; }

static NSString *DPHostOfTab(NSView *tab) {
    NSDictionary *views = DPSwiftValue(tab, @"contentViews");
    id url = DPSwiftValue(DPSwiftValue(DPSwiftValue(views.allValues.firstObject, @"viewModel"), @"delegate"), @"webContentURL");
    if ([url isKindOfClass:NSString.class]) url = [NSURL URLWithString:url];
    if (![url isKindOfClass:NSURL.class] || views.count != 1) return nil;
    NSString *scheme = [url scheme].lowercaseString;
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] ? [url host].lowercaseString : nil;
}

static BOOL DPTabSelected(NSView *tab) {
    NSString *style = [DPSwiftValue(DPSwiftValue(DPSwiftValue(DPSwiftValue(tab, @"viewModel"), @"stateSubject"), @"currentValue"), @"selectionStyle") description];
    return [style.lowercaseString hasSuffix:@"primary"];
}

static BOOL DPTabMarked(NSView *tab) { return DPDevMode.on && DPTabSelected(tab) && DPDevModeOn(DPHostOfTab(tab)); }

static CAShapeLayer *DPStroke(CGPathRef path, NSColor *color, NSArray *dashes) {
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = path;
    stroke.fillColor = nil;
    stroke.strokeColor = color.CGColor;
    stroke.lineWidth = DPOutlineWidth * 2;
    stroke.lineDashPattern = dashes;
    return stroke;
}

@interface DPTabMark : NSView  // Flipped like the view whose mask path it takes.
@property(nonatomic) id path;
@property(nonatomic) BOOL striped;
@end

@implementation DPTabMark
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)viewDidMoveToWindow {
    if (self.window) dispatch_async(dispatch_get_main_queue(), ^{ DPUpdateTabMarks(); });
}
@end

static BOOL DPInTabStrip(NSView *view) {
    while (view && !DPIsKind(view, DPDiaTabStrip)) view = view.superview;
    return view != nil;
}

// At the top the tab joins the striped toolbar, so it takes the stripes. In the sidebar it's outlined.
static DPTabMark *DPMakeMark(CGPathRef path, BOOL striped) {
    DPTabMark *mark = [DPTabMark new];
    mark.path = (__bridge id)path;
    mark.striped = striped;
    mark.layer = [CALayer layer];
    mark.wantsLayer = YES;
    mark.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    CAShapeLayer *inside = [CAShapeLayer layer];
    inside.path = path;
    mark.layer.mask = inside;
    if (striped) {
        [mark addSubview:DPMakeStripes()];
        return mark;
    }
    [mark.layer addSublayer:DPStroke(path, [NSColor colorWithSRGBRed:0.16 green:0.13 blue:0.02 alpha:1], nil)];
    [mark.layer addSublayer:DPStroke(path, [NSColor colorWithSRGBRed:0.98 green:0.78 blue:0.04 alpha:1], @[ @(DPDash), @(DPDash) ])];
    return mark;
}

static void DPUpdateTab(NSView *tab) {
    NSView *shape = DPShapeIn(tab);
    DPTabMark *mark = DPGet(tab, &DPMarkKey);
    CGPathRef path = shape && DPTabMarked(tab) ? DPShapePath(shape) : NULL;
    BOOL striped = path && DPInTabStrip(tab);
    NSAppearance *appearance = striped ? DPProfileAppearance(tab.window) : nil;
    // Dia gives the tab the site's appearance. Striped, its title takes the profile's, as the toolbar does.
    if (striped || mark.striped) {
        NSView *content = DPFindView(tab, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTabContentView); });
        if (content.appearance != appearance) content.appearance = appearance;
        NSView *fill = DPFillIn(shape);
        if (fill.alphaValue != !striped) fill.alphaValue = !striped;
    }
    if (!path) {
        [mark removeFromSuperview];
        return DPSet(tab, &DPMarkKey, nil);
    }
    if (!mark || mark.striped != striped || !CGPathEqualToPath(path, (__bridge CGPathRef)mark.path)) {
        [mark removeFromSuperview];
        DPSet(tab, &DPMarkKey, mark = DPMakeMark(path, striped));
    }
    if (mark.superview != shape || shape.subviews.lastObject != mark) [shape addSubview:mark positioned:NSWindowAbove relativeTo:nil];
    if (!NSEqualRects(mark.frame, shape.bounds)) mark.frame = shape.bounds;
    if (mark.appearance != appearance) mark.appearance = appearance;
}

void DPUpdateTabMarks(void) {
    for (NSView *tab in DPFindViews(DPDiaTabView)) DPUpdateTab(tab);
}

static void DPShape_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPShape_layout, self);
    NSView *tab = self;
    while (tab && !DPIsKind(tab, DPDiaTabView)) tab = tab.superview;
    if (tab) DPUpdateTab(tab);
}

// A tab sliding along the strip doesn't lay out, but its stripes have to stay in step with the toolbar's.
static void DPTab_setFrameOrigin(NSView *self, SEL _cmd, NSPoint origin) {
    DPCallOriginal(DPTab_setFrameOrigin, self, origin);
    DPTabMark *mark = DPGet(self, &DPMarkKey);
    if (mark.striped) mark.subviews.firstObject.needsLayout = YES;
}

void DPInstallTabMarks(void) {
    DPHook(DPDiaTabShape, @selector(layout), (IMP)DPShape_layout);
    DPHook(DPDiaTabView, @selector(setFrameOrigin:), (IMP)DPTab_setFrameOrigin);
}

NSString *DPVerifyTabMarks(void) {
    for (NSView *tab in DPFindViews(DPDiaTabView)) {
        NSView *shape = DPShapeIn(tab);
        if (!shape || !DPShapePath(shape)) continue;
        BOOL shown = [DPGet(tab, &DPMarkKey) superview] != nil;
        BOOL wanted = DPTabMarked(tab);
        if (shown != wanted) return wanted ? @"the selected Developer Mode tab isn't marked" : @"a tab outside Developer Mode is marked";
    }
    return nil;
}
