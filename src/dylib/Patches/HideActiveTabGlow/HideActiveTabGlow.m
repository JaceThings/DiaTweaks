#import "HideActiveTabGlow.h"

extern DPPatch DPHideActiveTabGlow;
static char DPDiaHiddenKey;
static NSHashTable *DPDecorations;
static const char *const DPDecorationIvars[] = {
    "$__lazy_storage_$_shadowLayer", "rimHighlightView", NULL
};

// Dia draws the shadow, fading outline and rim separately from the selected tab's fill.
static id DPDecorationIn(NSView *shape, const char *name) {
    void **slot = DPIvar(shape, name);
    id part = slot ? (__bridge id)*slot : nil;
    return [part isKindOfClass:CALayer.class] || [part isKindOfClass:NSView.class] ? part : nil;
}

// Selection and appearance changes can show the shadow again without laying out the tab.
static void DPDecoration_setHidden(id self, SEL _cmd, BOOL hidden) {
    if (DPGet(self, &DPDiaHiddenKey)) {
        DPSet(self, &DPDiaHiddenKey, @(hidden));
        hidden |= DPHideActiveTabGlow.on;
    }
    DPCallOriginal(DPDecoration_setHidden, self, hidden);
}

void DPHideTabDecoration(id part) {
    if (!part || !DPHideActiveTabGlow.on) return;
    NSNumber *dia = DPGet(part, &DPDiaHiddenKey);
    if (!dia) {
        DPSet(part, &DPDiaHiddenKey, dia = @([part isHidden]));
        [DPDecorations addObject:part];
        DPHookClass([part class], @selector(setHidden:), (IMP)DPDecoration_setHidden);
    }
    [part setHidden:dia.boolValue];
}

static void DPHideDecorations(NSView *shape) {
    if (!DPHideActiveTabGlow.on) return;
    for (const char *const *name = DPDecorationIvars; *name; name++) DPHideTabDecoration(DPDecorationIn(shape, *name));
    DPFlattenTabMaterial(shape);
    DPStyleUniformTabBorder(shape);
}

static void DPTabShape_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabShape_layout, self);
    DPHideDecorations(self);
}

static void DPApplyHideActiveTabGlow(DPPatch *patch) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (patch->on) {
        for (NSView *shape in DPFindViews(DPDiaTabShape)) DPHideDecorations(shape);
    } else {
        // Include parts from tabs that were detached or moved to another window.
        for (id part in DPDecorations.allObjects) {
            [part setHidden:[DPGet(part, &DPDiaHiddenKey) boolValue]];
            DPSet(part, &DPDiaHiddenKey, nil);
        }
        [DPDecorations removeAllObjects];
        DPRestoreTabBorders();
    }
    [CATransaction commit];
}

static NSString *DPVerifyHideActiveTabGlow(DPPatch *patch) {
    for (NSView *shape in DPFindViews(DPDiaTabShape)) {
        for (const char *const *name = DPDecorationIvars; *name; name++) {
            if (!DPIvar(shape, *name)) return @"tab decoration is unavailable";
            id part = DPDecorationIn(shape, *name);
            if (patch->on && part && (!DPGet(part, &DPDiaHiddenKey) || ![part isHidden])) return @"a tab still has its glow or border highlight";
            if (!patch->on && DPGet(part, &DPDiaHiddenKey)) return @"a tab decoration wasn't restored";
        }
        NSString *problem = DPVerifyFlatTabMaterial(shape, patch->on) ?: DPVerifyUniformTabBorder(shape, patch->on);
        if (problem) return problem;
    }
    return nil;
}

static void DPInstallHideActiveTabGlow(void) {
    DPDecorations = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaTabShape, @selector(layout), (IMP)DPTabShape_layout);
    DPInstallFlatTabMaterial();
}

DP_PATCH(DPHideActiveTabGlow) {
    .key = @"hideActiveTabGlow",
    .order = 82,
    .title = @"Hide Active Tab Glow",
    .detail = @"Remove the selected tab's glow and glass highlights, with a uniform border in the sidebar and tab bar.",
    .symbol = @"sun.max",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaTabShape),
    .install = DPInstallHideActiveTabGlow,
    .apply = DPApplyHideActiveTabGlow,
    .verify = DPVerifyHideActiveTabGlow,
};
