#import "StdPatch/StdPatch.h"

extern DPPatch DPDarkSelectedTab;

static char DPHiddenKey;
static char DPStyledKey;
static char DPGlowHostKey;
static char DPOuterBloomKey;
static char DPRimShimmerKey;

static void DPRestoreViewHidden(NSView *view) {
    if (!DPGet(view, &DPHiddenKey)) return;
    BOOL hidden = [DPDiaValue(view, &DPHiddenKey, @(view.hidden)) boolValue];
    DPSet(view, &DPHiddenKey, nil);
    view.hidden = hidden;
}

static void DPHideView(NSView *view, BOOL hide) {
    if (!view) return;
    if (hide) {
        DPOverride(view, &DPHiddenKey, DPDiaValue(view, &DPHiddenKey, @(view.hidden)), @YES);
        view.hidden = YES;
    } else {
        DPRestoreViewHidden(view);
    }
}

static void DPHideAllSubviews(NSView *root, BOOL hide) {
    for (NSView *sub in root.subviews) {
        DPHideView(sub, hide);
        DPHideAllSubviews(sub, hide);
    }
}

static void DPSyncHaloAnimations(CALayer *outerBloom, CAGradientLayer *rimShimmer, BOOL shouldAnimate, BOOL forceRestart) {
    if (!shouldAnimate) {
        [outerBloom removeAnimationForKey:@"dpElegantBloomOpacity"];
        [outerBloom removeAnimationForKey:@"dpElegantBloomRadius"];
        [rimShimmer removeAnimationForKey:@"dpConicRimRotation"];
        return;
    }

    outerBloom.speed = 1.0;
    outerBloom.timeOffset = 0.0;
    rimShimmer.speed = 1.0;
    rimShimmer.timeOffset = 0.0;

    if (forceRestart || ![outerBloom animationForKey:@"dpElegantBloomOpacity"]) {
        [outerBloom removeAnimationForKey:@"dpElegantBloomOpacity"];
        [outerBloom removeAnimationForKey:@"dpElegantBloomRadius"];

        CAMediaTimingFunction *ease = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

        CABasicAnimation *pulseOpacity = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        pulseOpacity.fromValue = @0.15;
        pulseOpacity.toValue = @0.32;
        pulseOpacity.duration = 4.0;
        pulseOpacity.autoreverses = YES;
        pulseOpacity.repeatCount = HUGE_VALF;
        pulseOpacity.timingFunction = ease;
        pulseOpacity.removedOnCompletion = NO;
        [outerBloom addAnimation:pulseOpacity forKey:@"dpElegantBloomOpacity"];

        CABasicAnimation *pulseRadius = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
        pulseRadius.fromValue = @6.5;
        pulseRadius.toValue = @11.5;
        pulseRadius.duration = 4.0;
        pulseRadius.autoreverses = YES;
        pulseRadius.repeatCount = HUGE_VALF;
        pulseRadius.timingFunction = ease;
        pulseRadius.removedOnCompletion = NO;
        [outerBloom addAnimation:pulseRadius forKey:@"dpElegantBloomRadius"];
    }

    if (forceRestart || ![rimShimmer animationForKey:@"dpConicRimRotation"]) {
        [rimShimmer removeAnimationForKey:@"dpConicRimRotation"];

        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @0.0;
        spin.toValue = @(M_PI * 2.0);
        spin.duration = 9.0;
        spin.repeatCount = HUGE_VALF;
        spin.removedOnCompletion = NO;
        [rimShimmer addAnimation:spin forKey:@"dpConicRimRotation"];
    }
}

static void DPStyleDarkTabWithRestart(NSView *shape, BOOL forceRestart) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    BOOL active = DPDarkSelectedTab.on;
    BOOL isSelectedTab = !shape.hidden;

    // 1. Hide Dia's internal white/glass subviews inside TabShapeView
    DPHideAllSubviews(shape, active);

    // 2. Keep sibling TabHighlightView hidden while selected so hover never washes out the sheer dark interior
    if (shape.superview) {
        for (NSView *sibling in shape.superview.subviews) {
            if (sibling != shape && [NSStringFromClass([sibling class]) hasSuffix:@"TabHighlightView"]) {
                DPHideView(sibling, active && isSelectedTab);
            }
        }
    }

    // 3. Suppress Dia's native lazy shadow & gradient border layers
    const char *const ivarNames[] = { "$__lazy_storage_$_shadowLayer", "$__lazy_storage_$_gradientBorderLayer", NULL };
    for (const char *const *name = ivarNames; *name; name++) {
        void **slot = DPIvar(shape, *name);
        CALayer *nativeLayer = slot ? (__bridge CALayer *)*slot : nil;
        if ([nativeLayer isKindOfClass:[CALayer class]]) {
            nativeLayer.hidden = active;
        }
    }

    shape.wantsLayer = YES;
    CALayer *layer = shape.layer;
    if (layer) {
        CALayer *glowHost = DPGet(shape, &DPGlowHostKey);
        CALayer *outerBloom = DPGet(shape, &DPOuterBloomKey);
        CAGradientLayer *rimShimmer = DPGet(shape, &DPRimShimmerKey);

        if (active) {
            DPSet(shape, &DPStyledKey, @YES);

            // Unclip immediate cell wrappers so the soft halo diffuses naturally
            layer.masksToBounds = NO;
            layer.speed = 1.0;
            NSView *up = shape.superview;
            for (int i = 0; i < 3 && up; i++, up = up.superview) {
                up.wantsLayer = YES;
                up.layer.masksToBounds = NO;
            }

            // Hide any extra native sublayers Dia attached directly to shape.layer
            CALayer *shimmerContainer = rimShimmer ? rimShimmer.superlayer : nil;
            for (CALayer *sublayer in [layer.sublayers copy]) {
                if (sublayer != glowHost && sublayer != shimmerContainer) {
                    sublayer.hidden = YES;
                }
            }

            CGRect bounds = shape.bounds;
            CGPathRef pillPath = CGPathCreateWithRoundedRect(bounds, 10.0, 10.0, NULL);

            // A. Sheer, flat smoky-dark interior
            layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.24].CGColor;
            layer.cornerRadius = 10.0;
            layer.cornerCurve = kCACornerCurveContinuous;
            layer.borderWidth = 0.75;
            layer.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.10].CGColor;
            layer.shadowOpacity = 0.0;
            layer.shadowRadius = 0.0;
            layer.shadowPath = nil;

            // B. Whisper-Soft Outward-Only Halo (Cutout mask keeps 100% of glow outside the pill)
            if (!glowHost) {
                glowHost = [CALayer layer];
                glowHost.masksToBounds = NO;
                [layer insertSublayer:glowHost atIndex:0];
                DPSet(shape, &DPGlowHostKey, glowHost);

                outerBloom = [CALayer layer];
                outerBloom.masksToBounds = NO;
                [glowHost addSublayer:outerBloom];
                DPSet(shape, &DPOuterBloomKey, outerBloom);
            }

            glowHost.frame = bounds;
            outerBloom.frame = bounds;

            CAShapeLayer *cutoutMask = (CAShapeLayer *)glowHost.mask;
            if (!cutoutMask) {
                cutoutMask = [CAShapeLayer layer];
                cutoutMask.fillRule = kCAFillRuleEvenOdd;
                glowHost.mask = cutoutMask;
            }
            cutoutMask.frame = bounds;
            CGMutablePathRef cutoutPath = CGPathCreateMutable();
            CGPathAddRect(cutoutPath, NULL, CGRectInset(bounds, -40.0, -40.0));
            CGPathRef innerCutout = CGPathCreateWithRoundedRect(CGRectInset(bounds, 0.5, 0.5), 9.5, 9.5, NULL);
            CGPathAddPath(cutoutPath, NULL, innerCutout);
            cutoutMask.path = cutoutPath;
            CGPathRelease(innerCutout);
            CGPathRelease(cutoutPath);

            glowHost.shadowColor = [NSColor colorWithCalibratedRed:0.96 green:0.98 blue:1.0 alpha:1.0].CGColor;
            glowHost.shadowOpacity = 0.28;
            glowHost.shadowRadius = 2.5;
            glowHost.shadowOffset = CGSizeZero;
            glowHost.shadowPath = pillPath;

            outerBloom.shadowColor = [NSColor colorWithCalibratedRed:0.86 green:0.93 blue:1.0 alpha:1.0].CGColor;
            outerBloom.shadowOpacity = 0.22;
            outerBloom.shadowRadius = 8.5;
            outerBloom.shadowOffset = CGSizeZero;
            outerBloom.shadowPath = pillPath;

            // C. 360-Degree Conic Specular Hairline Rim
            if (!rimShimmer) {
                rimShimmer = [CAGradientLayer layer];
                rimShimmer.type = kCAGradientLayerConic;
                rimShimmer.startPoint = CGPointMake(0.5, 0.5);
                rimShimmer.endPoint = CGPointMake(0.5, 0.0);

                shimmerContainer = [CALayer layer];
                [layer addSublayer:shimmerContainer];
                [shimmerContainer addSublayer:rimShimmer];
                DPSet(shape, &DPRimShimmerKey, rimShimmer);
            } else {
                shimmerContainer = rimShimmer.superlayer;
            }

            CGFloat maxDim = MAX(bounds.size.width, bounds.size.height) * 1.6;
            rimShimmer.bounds = CGRectMake(0, 0, maxDim, maxDim);
            rimShimmer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));

            id dimRim    = (__bridge id)[NSColor colorWithCalibratedWhite:1.0 alpha:0.08].CGColor;
            id softRim   = (__bridge id)[NSColor colorWithCalibratedRed:0.88 green:0.95 blue:1.0 alpha:0.28].CGColor;
            id brightRim = (__bridge id)[NSColor colorWithCalibratedWhite:1.0 alpha:0.78].CGColor;

            rimShimmer.colors = @[dimRim, softRim, brightRim, softRim, dimRim, softRim, brightRim, softRim, dimRim];
            rimShimmer.locations = @[@0.0, @0.10, @0.18, @0.26, @0.50, @0.60, @0.68, @0.76, @1.0];

            shimmerContainer.frame = bounds;

            CAShapeLayer *borderMask = (CAShapeLayer *)shimmerContainer.mask;
            if (!borderMask) {
                borderMask = [CAShapeLayer layer];
                borderMask.fillColor = [NSColor clearColor].CGColor;
                borderMask.strokeColor = [NSColor whiteColor].CGColor;
                borderMask.lineWidth = 1.0;
                shimmerContainer.mask = borderMask;
            }
            borderMask.frame = bounds;
            CGPathRef rimPath = CGPathCreateWithRoundedRect(CGRectInset(bounds, 0.5, 0.5), 9.5, 9.5, NULL);
            borderMask.path = rimPath;
            CGPathRelease(rimPath);

            // Only run animations while the tab is actually visible; cleanly clear when hidden
            BOOL shouldAnimate = isSelectedTab && (shape.window != nil);
            DPSyncHaloAnimations(outerBloom, rimShimmer, shouldAnimate, forceRestart);

            CGPathRelease(pillPath);
        } else if (DPGet(shape, &DPStyledKey)) {
            DPSet(shape, &DPStyledKey, nil);
            layer.backgroundColor = nil;
            layer.borderWidth = 0.0;
            layer.borderColor = nil;
            if (glowHost) {
                [outerBloom removeAllAnimations];
                [glowHost removeFromSuperlayer];
                DPSet(shape, &DPGlowHostKey, nil);
                DPSet(shape, &DPOuterBloomKey, nil);
            }
            if (rimShimmer) {
                [rimShimmer removeAllAnimations];
                [rimShimmer.superlayer removeFromSuperlayer];
                DPSet(shape, &DPRimShimmerKey, nil);
            }
            for (CALayer *sublayer in layer.sublayers) {
                sublayer.hidden = NO;
            }
        }
    }

    [CATransaction commit];
}

static void DPTabShape_darkRestyle(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabShape_darkRestyle, self);
    DPStyleDarkTabWithRestart(self, NO);
}

static void DPTabShape_movedToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabShape_movedToWindow, self);
    DPStyleDarkTabWithRestart(self, YES);
}

static void DPTabShape_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    BOOL wasHidden = self.hidden;
    DPCallOriginal(DPTabShape_setHidden, self, hidden);
    BOOL becomingVisible = (wasHidden && !hidden);
    DPStyleDarkTabWithRestart(self, becomingVisible);

    // Re-verify on the next main-queue pass in case Dia runs click animations right after setHidden:
    if (becomingVisible) {
        __weak NSView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSView *strongSelf = weakSelf;
            if (strongSelf && !strongSelf.hidden) {
                DPStyleDarkTabWithRestart(strongSelf, YES);
            }
        });
    }
}

static void DPApplyDarkSelectedTab(DPPatch *patch) {
    (void)patch;
    for (NSView *shape in DPFindViews(DPDiaTabShape)) {
        DPStyleDarkTabWithRestart(shape, YES);
    }
}

static NSString *DPVerifyDarkSelectedTab(DPPatch *patch) {
    for (NSView *shape in DPFindViews(DPDiaTabShape)) {
        if (patch->on && !DPGet(shape, &DPStyledKey)) {
            return @"selected tab is missing dark background";
        }
        if (!patch->on && DPGet(shape, &DPStyledKey)) {
            return @"selected tab dark background wasn't restored";
        }
    }
    return nil;
}

static void DPInstallDarkSelectedTab(void) {
    DPHook(DPDiaTabShape, @selector(layout), (IMP)DPTabShape_darkRestyle);
    DPHook(DPDiaTabShape, @selector(setHidden:), (IMP)DPTabShape_setHidden);
    DPHook(DPDiaTabShape, @selector(viewDidChangeEffectiveAppearance), (IMP)DPTabShape_darkRestyle);
    DPHook(DPDiaTabShape, @selector(viewDidMoveToSuperview), (IMP)DPTabShape_darkRestyle);
    DPHook(DPDiaTabShape, @selector(viewDidMoveToWindow), (IMP)DPTabShape_movedToWindow);
}

DP_PATCH(DPDarkSelectedTab) {
    .key = @"darkSelectedTab",
    .order = 127,
    .title = @"Dark Selected Tab",
    .detail = @"Sheer dark tab pill with a continuous 360° conic glass rim and ambient halo.",
    .symbol = @"sparkles",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaTabShape),
    .install = DPInstallDarkSelectedTab,
    .apply = DPApplyDarkSelectedTab,
    .verify = DPVerifyDarkSelectedTab,
};
