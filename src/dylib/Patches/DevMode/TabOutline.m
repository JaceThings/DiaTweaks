#import "DevMode.h"

static const CGFloat DPOutlineWidth = 1.5, DPDash = 6.5;
static char DPOutlineKey;

static NSView *DPShapeIn(NSView *tab) { return DPFindView(tab, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTabShape); }); }

// The selected tab's fill is clipped to Dia's own tab shape.
static CGPathRef DPShapePath(NSView *shape) {
    for (NSView *view in shape.subviews) {
        CAShapeLayer *mask = (CAShapeLayer *)view.layer.mask;
        if ([mask isKindOfClass:CAShapeLayer.class] && mask.path) return mask.path;
    }
    return NULL;
}

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

@interface DPOutlineView : NSView
@property (nonatomic) BOOL open;
@end

@implementation DPOutlineView
- (BOOL)isFlipped { return YES; }  // Like the view whose mask path it strokes.
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end

static BOOL DPInTabStrip(NSView *view) {
    while (view && !DPIsKind(view, DPDiaTabStrip)) view = view.superview;
    return view != nil;
}

static CGFloat DPWidthAt(CGPathRef path, CGFloat y) {
    CGPathRef strip = CGPathCreateWithRect(CGRectMake(-1e4, y - 1, 2e4, 2), NULL), slice = CGPathCreateCopyByIntersectingPath(path, strip, NO);
    CGFloat width = CGPathIsEmpty(slice) ? 0 : CGRectGetWidth(CGPathGetBoundingBox(slice));
    CGPathRelease(strip);
    CGPathRelease(slice);
    return width;
}

// At the top, the tab flares into the toolbar, so that edge stays open.
static CGPathRef DPCopyClipPath(CGPathRef path, BOOL open) {
    if (!open) return CGPathRetain(path);
    CGRect box = CGPathGetBoundingBox(path);
    BOOL flaresAtMin = DPWidthAt(path, CGRectGetMinY(box) + 1) > DPWidthAt(path, CGRectGetMaxY(box) - 1);
    CGRect kept = box;
    kept.size.height -= DPOutlineWidth;
    if (flaresAtMin) kept.origin.y += DPOutlineWidth;
    CGPathRef rect = CGPathCreateWithRect(kept, NULL), clip = CGPathCreateCopyByIntersectingPath(path, rect, NO);
    CGPathRelease(rect);
    return clip;
}

static DPOutlineView *DPMakeOutline(CGPathRef path, BOOL open) {
    DPOutlineView *view = [DPOutlineView new];
    view.open = open;
    view.layer = [CALayer layer];
    view.wantsLayer = YES;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [view.layer addSublayer:DPStroke(path, [NSColor colorWithSRGBRed:0.16 green:0.13 blue:0.02 alpha:1], nil)];
    [view.layer addSublayer:DPStroke(path, [NSColor colorWithSRGBRed:0.98 green:0.78 blue:0.04 alpha:1], @[ @(DPDash), @(DPDash) ])];
    CAShapeLayer *inside = [CAShapeLayer layer];
    CGPathRef clip = DPCopyClipPath(path, open);
    inside.path = clip;
    CGPathRelease(clip);
    view.layer.mask = inside;
    return view;
}

static void DPUpdateTab(NSView *tab) {
    NSView *shape = DPShapeIn(tab);
    DPOutlineView *outline = DPGet(tab, &DPOutlineKey);
    CGPathRef path = shape && DPTabMarked(tab) ? DPShapePath(shape) : NULL;
    if (!path) return [outline removeFromSuperview];
    BOOL open = DPInTabStrip(tab);
    if (!outline || outline.open != open || !CGPathEqualToPath(path, ((CAShapeLayer *)outline.layer.sublayers.firstObject).path)) {
        [outline removeFromSuperview];
        DPSet(tab, &DPOutlineKey, outline = DPMakeOutline(path, open));
    }
    if (outline.superview != shape || shape.subviews.lastObject != outline) [shape addSubview:outline positioned:NSWindowAbove relativeTo:nil];
    if (!NSEqualRects(outline.frame, shape.bounds)) outline.frame = shape.bounds;
}

void DPUpdateTabOutlines(void) {
    for (NSView *tab in DPFindViews(DPDiaTabView)) DPUpdateTab(tab);
}

static void DPShape_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPShape_layout, self);
    NSView *tab = self;
    while (tab && !DPIsKind(tab, DPDiaTabView)) tab = tab.superview;
    if (tab) DPUpdateTab(tab);
}

void DPInstallTabOutlines(void) { DPHook(DPDiaTabShape, @selector(layout), (IMP)DPShape_layout); }

NSString *DPVerifyTabOutlines(void) {
    for (NSView *tab in DPFindViews(DPDiaTabView)) {
        NSView *shape = DPShapeIn(tab);
        if (!shape || !DPShapePath(shape)) continue;
        BOOL shown = [DPGet(tab, &DPOutlineKey) superview] != nil;
        BOOL wanted = DPTabMarked(tab);
        if (shown != wanted) return wanted ? @"the selected Developer Mode tab isn't marked" : @"a tab outside Developer Mode is marked";
    }
    return nil;
}
