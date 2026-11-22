#import "TrueBlack.h"

// With tabs at the top, the selected tab takes the site's color, which on a dark site is close to black.
// On the black strip only its rim, a faint white stroke, shows where it is, so the rim gets brighter.
static const float DPRimBoost = 2.4;
static char DPRimKey;

static BOOL DPIsTopTab(NSView *rim) {
    for (NSView *up = rim.superview; up; up = up.superview)
        if (DPIsKind(up, DPDiaTabStrip)) return YES;
    return NO;
}

static BOOL DPOutlines(NSView *rim) { return DPBlackens(rim) && DPIsTopTab(rim); }

static CAShapeLayer *DPStrokeOf(NSView *rim) {
    for (CALayer *layer in rim.layer.sublayers)
        if ([layer isKindOfClass:CAShapeLayer.class] && ((CAShapeLayer *)layer).strokeColor) return (CAShapeLayer *)layer;
    return nil;
}

static float DPBoosted(NSNumber *dia) { return MIN(1, dia.floatValue * DPRimBoost); }

static void DPOutline(NSView *rim) {
    CAShapeLayer *stroke = DPStrokeOf(rim);
    if (!stroke || (!DPOutlines(rim) && !DPGet(stroke, &DPRimKey))) return;
    NSNumber *dia = DPDiaValue(stroke, &DPRimKey, @(stroke.opacity));
    NSNumber *ours = DPOutlines(rim) ? @(DPBoosted(dia)) : dia;
    DPSet(stroke, &DPRimKey, DPOutlines(rim) ? @[ dia, ours ] : nil);
    if (stroke.opacity == ours.floatValue) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    stroke.opacity = ours.floatValue;
    [CATransaction commit];
}

static void DPRim_outline(NSView *self, SEL _cmd) {
    DPCallOriginal(DPRim_outline, self);
    DPOutline(self);
}

void DPInstallTabOutline(void) {
    DPHook(DPDiaTabRim, @selector(layout), (IMP)DPRim_outline);
    DPHook(DPDiaTabRim, @selector(viewDidChangeEffectiveAppearance), (IMP)DPRim_outline);
    DPHook(DPDiaTabRim, @selector(viewDidMoveToWindow), (IMP)DPRim_outline);
}

void DPApplyTabOutline(void) {
    for (NSView *rim in DPFindViews(DPDiaTabRim)) DPOutline(rim);
}

NSString *DPVerifyTabOutline(void) {
    for (NSView *rim in DPFindViews(DPDiaTabRim)) {
        CAShapeLayer *stroke = DPStrokeOf(rim);
        if (!stroke || rim.hiddenOrHasHiddenAncestor) continue;
        NSNumber *dia = DPDiaValue(stroke, &DPRimKey, @(stroke.opacity));
        if (DPOutlines(rim) && (!DPGet(stroke, &DPRimKey) || stroke.opacity != DPBoosted(dia))) return @"selected tab's outline isn't brighter";
        if (!DPOutlines(rim) && DPGet(stroke, &DPRimKey)) return @"selected tab kept the brighter outline";
    }
    return nil;
}
