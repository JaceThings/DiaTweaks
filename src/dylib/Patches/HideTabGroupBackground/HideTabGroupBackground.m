#import "StdPatch/StdPatch.h"

extern DPPatch DPHideTabGroupBackground;
static char DPBorderKey;

// An open group with no colour of its own gets a grey, black or white at low opacity. A colour picked for it never is.
static BOOL DPIsGrey(CGColorRef color) {
    NSColor *rgb = [[NSColor colorWithCGColor:color] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if (!rgb) return NO;
    CGFloat r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent;
    return fabs(r - g) < 0.02 && fabs(g - b) < 0.02;
}

// The grey comes with a hairline border and a faint inner shadow, which go too. A coloured group keeps all three.
static void DPStyleBackground(NSView *cell) {
    CALayer *layer = DPSubview(cell, DPDiaTabGroupBackground).layer;
    if (!layer.backgroundColor) return;
    BOOL hide = DPHideTabGroupBackground.on && DPIsGrey(layer.backgroundColor);
    if (hide) layer.backgroundColor = nil;
    for (CALayer *shadow in layer.sublayers) shadow.hidden = hide;
    // Dia sets the border once, so its width is kept to put back.
    NSNumber *border = DPGet(layer, &DPBorderKey);
    if (!border) DPSet(layer, &DPBorderKey, border = @(layer.borderWidth));
    layer.borderWidth = hide ? 0 : border.doubleValue;
}

// Dia sets the colour each time the cell redraws, so it's checked after, and turning off is a redraw.
static void DPGroupCell_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGroupCell_updateLayer, self);
    DPStyleBackground(self);
}

static void DPApplyHideTabGroupBackground(DPPatch *patch) {
    for (NSView *cell in DPFindViews(DPDiaTabGroupCell)) cell.needsDisplay = YES;
}

static NSString *DPVerifyHideTabGroupBackground(DPPatch *patch) {
    if (!patch->on) return nil;
    for (NSView *background in DPFindViews(DPDiaTabGroupBackground))
        if (background.layer.backgroundColor && DPIsGrey(background.layer.backgroundColor)) return @"a tab group is still grey";
    return nil;
}

static void DPInstallHideTabGroupBackground(void) {
    DPHook(DPDiaTabGroupCell, @selector(updateLayer), (IMP)DPGroupCell_updateLayer);
}

DP_PATCH(DPHideTabGroupBackground) {
    .key = @"hideTabGroupBackground",
    .order = 81,
    .title = @"Hide Tab Group Background",
    .detail = @"Leave an open tab group without the grey behind it, unless you've picked a colour for the group.",
    .symbol = @"square.stack.fill square.fill",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaTabGroupCell, DPDiaTabGroupBackground),
    .install = DPInstallHideTabGroupBackground,
    .apply = DPApplyHideTabGroupBackground,
    .verify = DPVerifyHideTabGroupBackground,
};
