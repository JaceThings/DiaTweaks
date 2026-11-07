#if defined(DP_ACTIVE_TAB_GLOW_TEST)
#import "../HideActiveTabGlow.m"
#import "../UniformBorder.m"
#import "../FlatMaterial.m"

static NSArray<NSView *> *visibleShapes;
static const char *const Names[] = {"$__lazy_storage_$_shadowLayer", "$__lazy_storage_$_gradientBorderLayer", "rimHighlightView", NULL};
static Class shapeClass;
static NSUInteger layouts;
NSArray<NSView *> *DPFindViews(const char *name) { return visibleShapes; }
static id Part(NSView *shape, NSUInteger index) { return (__bridge id)*(void **)DPIvar(shape, Names[index]); }
static void SetPart(NSView *shape, NSUInteger index, id part) {
    objc_setAssociatedObject(shape, Names[index], part, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    *(void **)DPIvar(shape, Names[index]) = (__bridge void *)part;
}
static void FixtureLayout(NSView *shape, SEL sel) {
    layouts++;
    if (!Part(shape, 0)) SetPart(shape, 0, [CALayer layer]);
    if (!Part(shape, 1)) SetPart(shape, 1, [CAGradientLayer layer]);
    if (!Part(shape, 2)) SetPart(shape, 2, [NSView new]);
}
static void Check(BOOL yes, NSString *message) {
    if (!yes) { NSLog(@"FAIL: %@", message); exit(1); }
}
static void Toggle(BOOL on) { DPHideActiveTabGlow.on = on; DPHideActiveTabGlow.apply(&DPHideActiveTabGlow); }
static id C(CGFloat white, CGFloat alpha) { return (__bridge id)[NSColor colorWithWhite:white alpha:alpha].CGColor; }

int main(void) { @autoreleasepool {
    shapeClass = objc_allocateClassPair(NSView.class, DPDiaTabShape, 0);
    for (const char *const *name = Names; *name; name++)
        Check(class_addIvar(shapeClass, *name, sizeof(void *), 3, "@"), @"ivar registration");
    class_addMethod(shapeClass, @selector(layout), (IMP)FixtureLayout, "v@:");
    objc_registerClassPair(shapeClass);
    NSView *shape = [[shapeClass alloc] initWithFrame:NSMakeRect(0,0,311,34)];
    FixtureLayout(shape, @selector(layout));
    visibleShapes = @[shape];
    DPHideActiveTabGlow.install();
    CALayer *shadow = Part(shape, 0);
    NSView *rim = Part(shape, 2);
    CAGradientLayer *border = Part(shape, 1);
    NSArray *palette = @[C(1,.3),C(1,.15),C(1,.15),C(1,0),C(1,.15),C(1,.15),C(1,.3)];
    border.colors = palette;
    NSArray *locations = @[@0,@.1,@.2,@.5,@.8,@.9,@1]; border.locations = locations;
    CALayer *mask = [CALayer layer]; border.mask = mask;
    Toggle(YES);
    Check(shadow.hidden && rim.hidden && !border.hidden, @"glow and rim suppressed while the border remains visible");
    Check(border.colors.count == palette.count && [border.colors.firstObject isEqual:palette[1]], @"native median-opacity color used for the border");
    Check([border.colors isEqual:DPUniformColors(border.colors)], @"all stops have the same color");
    Check(border.mask == mask && [border.locations isEqual:locations], @"native border geometry is untouched");
    Check(!DPHideActiveTabGlow.verify(&DPHideActiveTabGlow), @"enabled verification");
    shadow.hidden = NO; rim.hidden = NO;
    Check(shadow.hidden && rim.hidden, @"Dia cannot re-show suppressed decorations");
    NSArray *dark = @[C(0,.1),C(0,.2),C(0,.3)]; border.colors = dark;
    Check([border.colors.firstObject isEqual:dark[1]] && [border.colors isEqual:DPUniformColors(border.colors)], @"new appearance colors stay uniform");
    Toggle(NO);
    Check(!shadow.hidden && !rim.hidden && [border.colors isEqual:dark], @"off restores the latest native state");
    Check(!DPHideActiveTabGlow.verify(&DPHideActiveTabGlow), @"disabled verification");
    shadow.hidden = YES; rim.hidden = YES; Toggle(YES); Toggle(NO);
    Check(shadow.hidden && rim.hidden, @"pre-hidden decorations remain hidden");
    shadow.hidden = NO; rim.hidden = NO;

    NSView *late = [[shapeClass alloc] initWithFrame:NSMakeRect(0,0,311,34)];
    visibleShapes = @[late]; Toggle(YES); [late layout];
    Check([Part(late,0) isHidden] && [Part(late,2) isHidden], @"lazy decorations are suppressed after original layout");
    visibleShapes = @[]; Toggle(NO);
    Check(![Part(late,0) isHidden] && ![Part(late,2) isHidden], @"detached decorations are restored");

    visibleShapes = @[shape];
    Class glassClass = NSClassFromString(@"NSGlassEffectView");
    if (glassClass) {
        NSView *glass = [[glassClass alloc] initWithFrame:NSMakeRect(0,0,311,34)];
        NSView *otherGlass = [[glassClass alloc] initWithFrame:NSMakeRect(0,0,311,34)];
        [shape addSubview:glass]; Toggle(YES);
        Check(glass.hidden && !otherGlass.hidden, @"only tab glass is suppressed");
        glass.hidden = NO; Check(glass.hidden, @"tab glass stays hidden after a material update");
        NSView *lateGlass = [[glassClass alloc] initWithFrame:NSMakeRect(0,0,311,34)];
        [shape addSubview:lateGlass]; Check(lateGlass.hidden, @"new glass is suppressed immediately when attached to a tab");
        Toggle(NO);
        Check(!glass.hidden && !lateGlass.hidden && !otherGlass.hidden, @"off restores tab glass while other glass stays intact");
    }
    CAGradientLayer *otherBorder = [CAGradientLayer layer];
    for (int i=0; i<100; i++) { Toggle(YES); border.colors=palette; otherBorder.colors=palette; Toggle(NO); }
    Check([border.colors isEqual:palette] && [otherBorder.colors isEqual:palette], @"100 toggles restore colors and leave unrelated gradients alone");
    Check(DPDecorations.count == 0 && DPBorders.count == 0 && layouts == 2, @"no suppressed objects left and original layout ran");
    DPHideActiveTabGlow.on = YES;
    Check(DPHideActiveTabGlow.verify(&DPHideActiveTabGlow) != nil, @"verification catches missing enforcement");
    DPHideActiveTabGlow.on = NO;
    puts("PASS: uniform border and native geometry, appearance changes, restoration, lazy/detached views, scoped glass suppression, late glass attachment and 100 toggles");
} }

#endif
