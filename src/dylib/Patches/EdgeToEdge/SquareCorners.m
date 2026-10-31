#import "EdgeToEdge.h"

static char DPPathKey;

// Rounds the page's left corners down to square by `square`, with a two-half mask while it animates.
static void DPMaskCorners(CALayer *layer, CGFloat square) {
    CACornerMask left = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner, right = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
    if (square == 0 || square == 1) {
        layer.mask = nil;
        layer.maskedCorners = square == 1 ? right : left | right;
        return;
    }
    CALayer *mask = layer.mask.sublayers.count == 2 ? layer.mask : [CALayer layer];
    if (mask != layer.mask) {
        for (int i = 0; i < 2; i++) {
            CALayer *half = [CALayer layer];
            half.backgroundColor = NSColor.blackColor.CGColor;
            half.cornerCurve = kCACornerCurveContinuous;
            half.maskedCorners = i ? right : left;
            [mask addSublayer:half];
        }
    }
    CGRect bounds = layer.bounds;
    CGFloat half = CGRectGetWidth(bounds) / 2;
    mask.frame = bounds;
    mask.sublayers[0].frame = CGRectMake(0, 0, half + 1, CGRectGetHeight(bounds));
    mask.sublayers[1].frame = CGRectMake(half - 1, 0, half + 1, CGRectGetHeight(bounds));
    mask.sublayers[0].cornerRadius = layer.cornerRadius * (1 - square);
    mask.sublayers[1].cornerRadius = layer.cornerRadius;
    layer.mask = mask;
    layer.maskedCorners = 0;
}

// Dia draws the page's shadow and border as full-width paths, which get the same corners.
static void DPReshapePaths(NSView *container, CGFloat base, CGFloat grow, CGFloat square) {
    for (NSView *sub in container.subviews)
        for (CALayer *sublayer in sub.layer.sublayers) {
            CAShapeLayer *shape = [sublayer isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)sublayer
                                : [sublayer.mask isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)sublayer.mask : nil;
            if (!shape.path || CGRectGetWidth(CGPathGetBoundingBox(shape.path)) < NSWidth(container.bounds) * 0.9) continue;
            id current = (__bridge id)shape.path;
            id dia = DPDiaValue(shape, &DPPathKey, current);
            if (dia == current) dia = CFBridgingRelease(CGPathCreateCopy(shape.path));
            CGPathRef path = DPReshapeCorners((__bridge CGPathRef)dia, base * 1.6, grow, grow * (1 - square));
            if (!CGPathEqualToPath(path, shape.path)) shape.path = path;
            DPOverride(shape, &DPPathKey, dia, (__bridge id)shape.path);
        }
}

BOOL DPBesideSidebar(NSView *container) {
    return NSMinX(container.frame) > DPWindowPadding + 1 && !DPChatCard(container);
}

void DPApplySquareCorners(NSView *container) {
    CALayer *layer = DPRoundedContent(container).layer;
    if (!layer) return;
    layer.cornerCurve = kCACornerCurveContinuous;
    CGFloat square = DPBesideSidebar(container) ? DPSquareSidebarCorners.progress * DPEdgeToEdge.progress : 0;
    CGFloat base = DPBaseCornerRadius(container) ?: layer.cornerRadius;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    DPMaskCorners(layer, square);
    DPReshapePaths(container, base, base > 0 ? layer.cornerRadius / base : 1, square);
    [CATransaction commit];
}

static NSString *DPVerifySquareCorners(DPPatch *patch) {
    CACornerMask right = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner, all = right | kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;
    for (NSView *container in DPFindViews(DPDiaContentContainer)) {
        CALayer *layer = DPRoundedContent(container).layer;
        if (!layer) return @"no rounded web content found";
        BOOL square = patch->on && DPEdgeToEdge.on && DPBesideSidebar(container);
        if (layer.mask || layer.maskedCorners != (square ? right : all)) return square ? @"corners by the sidebar are round" : @"corners by the sidebar are square";
    }
    return nil;
}

DP_PATCH(DPSquareSidebarCorners) {
    .key = @"squareSidebarCorners",
    .defaultOn = YES,
    .order = 20,
    .title = @"Square corners by the sidebar",
    .detail = @"Let web pages meet the sidebar with straight edges.",
    .symbol = @"square",
    .tint = @"systemIndigoColor",
    .requires = @"edgeToEdge",
    .verify = DPVerifySquareCorners,
};
