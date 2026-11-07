#import "HideVerticalTabGlow.h"

static const char *const DPDecorationIvars[] = { "$__lazy_storage_$_shadowLayer", "rimHighlightView", NULL };

static void DPStyleTab(NSView *shape) {
    BOOL active = DPHideVerticalTabGlow.on && DPIsVerticalTab(shape);
    for (const char *const *name = DPDecorationIvars; *name; name++) {
        id part = DPTabDecoration(shape, *name);
        if (active) DPHideTabDecoration(part, shape);
        else DPRestoreTabDecoration(part);
    }
    DPFlattenTabMaterial(shape, shape);
    DPStyleUniformTabBorder(shape);
}

static void DPTabShape_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabShape_layout, self);
    DPStyleTab(self);
}

static void DPTabShape_didMove(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabShape_didMove, self);
    DPStyleTab(self);
}

static void DPApplyHideVerticalTabGlow(DPPatch *patch) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (patch->on) for (NSView *shape in DPFindViews(DPDiaTabShape)) DPStyleTab(shape);
    else { DPRestoreTabDecorations(); DPRestoreTabBorders(); }
    [CATransaction commit];
}

static NSString *DPVerifyHideVerticalTabGlow(DPPatch *patch) {
    for (NSView *shape in DPFindViews(DPDiaTabShape)) {
        BOOL active = patch->on && DPIsVerticalTab(shape);
        for (const char *const *name = DPDecorationIvars; *name; name++) {
            if (active && !DPIvar(shape, *name)) return @"tab decoration is unavailable";
            id part = DPTabDecoration(shape, *name);
            if (active && part && (!DPHasTabOverride(part) || ![part isHidden])) return @"a vertical tab still has its glow";
            if (!active && DPHasTabOverride(part)) return @"a tab decoration wasn't restored";
        }
        NSString *problem = DPVerifyFlatTabMaterial(shape, active) ?: DPVerifyUniformTabBorder(shape, active);
        if (problem) return problem;
    }
    return nil;
}

static void DPInstallHideVerticalTabGlow(void) {
    DPInstallTabDecorations();
    DPHook(DPDiaTabShape, @selector(layout), (IMP)DPTabShape_layout);
    DPHook(DPDiaTabShape, @selector(viewDidMoveToSuperview), (IMP)DPTabShape_didMove);
    DPHook(DPDiaTabShape, @selector(viewDidMoveToWindow), (IMP)DPTabShape_didMove);
    DPInstallFlatTabMaterial();
}

DP_PATCH(DPHideVerticalTabGlow) {
    .key = @"hideVerticalTabGlow",
    .order = 82,
    .title = @"Hide Vertical Tab Glow",
    .detail = @"Remove the selected sidebar tab's glow and glass highlights, with a uniform border.",
    .symbol = @"sun.max",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaTabShape, DPVerticalSidebarRoot, DPDiaTabStrip),
    .install = DPInstallHideVerticalTabGlow,
    .apply = DPApplyHideVerticalTabGlow,
    .verify = DPVerifyHideVerticalTabGlow,
};
