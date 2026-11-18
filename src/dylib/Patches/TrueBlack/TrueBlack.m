#import "StdPatch/StdPatch.h"

extern DPPatch DPTrueBlack;
static char DPGradientKey;

static CGColorRef DPBlack(void) { return CGColorGetConstantColor(kCGColorBlack); }

static BOOL DPIsDark(NSView *view) {
    NSAppearanceName match = [view.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
    return [match isEqualToString:NSAppearanceNameDarkAqua];
}

// Light text on black only: a light profile keeps its color.
static BOOL DPBlackens(NSView *view) { return DPTrueBlack.on && DPIsDark(view); }

// The window's and the floating sidebar's own tint, not the selected tab's copy, which sits deeper.
static BOOL DPIsChromeTint(NSView *tint) {
    NSView *host = tint.superview.superview;
    return DPIsKind(tint, DPDiaWindowTint) && (DPIsKind(host, DPDiaWindowFrame) || DPIsKind(host, DPDiaFloatingSidebar));
}

// The tint's wash and the toolbar's background, not the toolbar's 1pt separator.
static BOOL DPIsChromeColor(NSView *view) {
    NSView *parent = view.superview;
    if (DPIsChromeTint(parent)) return YES;
    return DPIsKind(parent, DPDiaToolbar) && parent.subviews.firstObject == view;
}

static void DPPaint(NSView *view) {
    if (DPIsChromeColor(view) && DPBlackens(view) && !CGColorEqualToColor(view.layer.backgroundColor, DPBlack()))
        view.layer.backgroundColor = DPBlack();
}

// The gradient sits over the wash and would lighten it.
static void DPApplyGradient(NSView *gradient) {
    if (!gradient.layer || !DPIsChromeTint(gradient.superview)) return;
    NSNumber *dia = DPDiaValue(gradient, &DPGradientKey, @(gradient.layer.opacity));
    NSNumber *ours = DPBlackens(gradient) ? @0 : dia;
    DPOverride(gradient, &DPGradientKey, dia, ours);
    if (gradient.layer.opacity != ours.floatValue) gradient.layer.opacity = ours.floatValue;
}

static void DPColor_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPColor_updateLayer, self);
    DPPaint(self);
}

static void DPGradient_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGradient_updateLayer, self);
    DPApplyGradient(self);
}

static void DPGradient_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGradient_layout, self);
    DPApplyGradient(self);
}

static void DPInstallTrueBlack(void) {
    DPHook(DPDiaColorView, @selector(updateLayer), (IMP)DPColor_updateLayer);
    DPHook(DPDiaGradientView, @selector(updateLayer), (IMP)DPGradient_updateLayer);
    DPHook(DPDiaGradientView, @selector(layout), (IMP)DPGradient_layout);
}

// Off, updateLayer puts Dia's color back.
static void DPApplyTrueBlack(DPPatch *patch) {
    for (NSView *view in DPFindViews(DPDiaColorView)) {
        if (!DPIsChromeColor(view)) continue;
        view.needsDisplay = YES;
        DPPaint(view);
    }
    for (NSView *view in DPFindViews(DPDiaGradientView)) DPApplyGradient(view);
}

static NSString *DPVerifyTrueBlack(DPPatch *patch) {
    for (NSView *view in DPFindViews(DPDiaColorView)) {
        if (!DPIsChromeColor(view) || view.hiddenOrHasHiddenAncestor) continue;
        BOOL black = CGColorEqualToColor(view.layer.backgroundColor, DPBlack()), toolbar = DPIsKind(view.superview, DPDiaToolbar);
        if (DPBlackens(view) && !black) return toolbar ? @"toolbar isn't black" : @"window color isn't black";
        if (!DPBlackens(view) && black) return toolbar ? @"toolbar stayed black" : @"window color stayed black";
    }
    for (NSView *view in DPFindViews(DPDiaGradientView)) {
        if (!DPIsChromeTint(view.superview) || view.hiddenOrHasHiddenAncestor) continue;
        BOOL hidden = view.layer.opacity == 0;
        if (DPBlackens(view) && !hidden) return @"window gradient still shows";
        if (!DPBlackens(view) && hidden && [DPDiaValue(view, &DPGradientKey, @0) floatValue] != 0) return @"window gradient still hidden";
    }
    return nil;
}

DP_PATCH(DPTrueBlack) {
    .key = @"trueBlack",
    .order = 100,
    .title = @"True Black",
    .detail = @"Paint the sidebar, tab bar, toolbar and window edges pure black in dark mode, instead of the profile’s color.",
    .symbol = @"moon.fill circle.fill",
    .tint = @"systemBrownColor",
    .section = @"Window",
    .classes = DPClasses(DPDiaWindowFrame, DPDiaWindowTint, DPDiaColorView, DPDiaGradientView, DPDiaToolbar),
    .install = DPInstallTrueBlack,
    .apply = DPApplyTrueBlack,
    .verify = DPVerifyTrueBlack,
};
