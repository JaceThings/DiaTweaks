#import "HideActiveTabGlow.h"

static BOOL DPIsGlass(NSView *view) {
    Class glass = NSClassFromString(@"NSGlassEffectView");
    return glass && [view isKindOfClass:glass];
}

void DPFlattenTabMaterial(NSView *shape) {
    if (DPIsGlass(shape)) DPHideTabDecoration(shape);
    for (NSView *sub in shape.subviews) DPFlattenTabMaterial(sub);
}

NSString *DPVerifyFlatTabMaterial(NSView *shape, BOOL on) {
    if (on && DPIsGlass(shape) && !shape.hidden) return @"a tab still has its glass highlight";
    for (NSView *sub in shape.subviews) {
        NSString *problem = DPVerifyFlatTabMaterial(sub, on);
        if (problem) return problem;
    }
    return nil;
}

// Window Material can create or reattach glass after the tab has already laid out.
static void DPGlass_viewDidMoveToSuperview(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGlass_viewDidMoveToSuperview, self);
    for (NSView *up = self.superview; up; up = up.superview)
        if (DPIsKind(up, DPDiaTabShape)) return DPHideTabDecoration(self);
}

void DPInstallFlatTabMaterial(void) {
    Class glass = NSClassFromString(@"NSGlassEffectView");
    if (glass) DPHookClass(glass, @selector(viewDidMoveToSuperview), (IMP)DPGlass_viewDidMoveToSuperview);
}
