static void TestLayoutScopes(NSView *shape, NSView *sidebar, Class stripClass, NSArray *palette) {
    NSView *strip = [[stripClass alloc] initWithFrame:NSMakeRect(0,0,800,34)];
    NSView *horizontal = [[shapeClass alloc] initWithFrame:NSMakeRect(0,0,160,34)];
    SetPart(horizontal,0,[CALayer layer]); SetPart(horizontal,1,[CAGradientLayer layer]); SetPart(horizontal,2,[NSView new]);
    CAGradientLayer *border = Part(horizontal,1); border.colors = palette;
    [strip addSubview:horizontal]; visibleShapes = @[shape,horizontal];
    Toggle(YES);
    Check([Part(shape,0) isHidden] && ![Part(horizontal,0) isHidden], @"only the vertical tab loses its shadow");
    Check(![Part(horizontal,2) isHidden] && [border.colors isEqual:palette], @"horizontal rim and fading border are unchanged");
    Check(!DPHideVerticalTabGlow.verify(&DPHideVerticalTabGlow), @"mixed layouts verify independently");
    NSArray *changed = @[C(0,.1),C(0,.2),C(0,.3)]; border.colors = changed;
    Check([border.colors isEqual:changed], @"horizontal appearance writes pass through untouched");

    Class glassClass = NSClassFromString(@"NSGlassEffectView");
    if (glassClass) {
        NSView *glass = [[glassClass alloc] initWithFrame:NSMakeRect(0,0,160,34)];
        [horizontal addSubview:glass];
        Check(!glass.hidden && !DPHasTabOverride(glass), @"late horizontal glass stays native");
        [shape addSubview:glass];
        Check(glass.hidden, @"glass moved into a vertical tab is suppressed");
        [horizontal addSubview:glass];
        Check(!glass.hidden && !DPHasTabOverride(glass), @"glass moved out of a vertical tab is restored");
    }

    // A horizontal strip stays excluded even if it is temporarily nested under a sidebar root.
    [sidebar addSubview:strip]; [horizontal layout];
    Check(!DPIsVerticalTab(horizontal) && [border.colors isEqual:changed], @"horizontal root wins over any enclosing sidebar");
    [strip addSubview:shape];
    Check(![Part(shape,0) isHidden] && ![Part(shape,2) isHidden], @"vertical-to-horizontal move restores shadow and rim immediately");
    CAGradientLayer *movedBorder = Part(shape,1);
    Check([movedBorder.colors isEqual:palette], @"vertical-to-horizontal move restores native border colors");
    movedBorder.colors = changed;
    Check([movedBorder.colors isEqual:changed], @"moved tab's horizontal color updates remain native");
    [sidebar addSubview:shape];
    Check([Part(shape,0) isHidden] && [movedBorder.colors isEqual:DPUniformColors(changed)], @"horizontal-to-vertical move applies styling again");

    NSView *outside = [[shapeClass alloc] initWithFrame:NSMakeRect(0,0,160,34)];
    SetPart(outside,0,[CALayer layer]); SetPart(outside,1,[CAGradientLayer layer]); SetPart(outside,2,[NSView new]);
    CAGradientLayer *outsideBorder = Part(outside,1); outsideBorder.colors = palette;
    visibleShapes = @[shape,horizontal,outside];
    DPApplyHideVerticalTabGlow(&DPHideVerticalTabGlow);
    Check(![Part(outside,0) isHidden] && [outsideBorder.colors isEqual:palette], @"tabs outside a sidebar are left untouched");
    Toggle(NO); visibleShapes = @[shape];
    Check(DPDecorations.count == 0 && DPBorders.count == 0, @"layout tests leave no overrides behind");
}
