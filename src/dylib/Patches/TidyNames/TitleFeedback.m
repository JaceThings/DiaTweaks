#import "Feedback.h"

NSView *DPTidyTabFavicon(id content);
NSTextField *DPTidyTabContentTitle(NSView *row);

static CALayer *DPTidySweep(NSView *target, BOOL isTitle, BOOL repeating) {
    if (!target.window || target.hiddenOrHasHiddenAncestor || NSIsEmptyRect(target.bounds)) return nil;
    NSBitmapImageRep *bitmap = [target bitmapImageRepForCachingDisplayInRect:target.bounds];
    if (!bitmap.hasAlpha) return nil;
    [target cacheDisplayInRect:target.bounds toBitmapImageRep:bitmap];
    if (isTitle && [bitmap colorAtX:0 y:0].alphaComponent > 0.01 &&
        [bitmap colorAtX:bitmap.pixelsWide - 1 y:bitmap.pixelsHigh - 1].alphaComponent > 0.01) return nil;

    // Capture the drawn glyphs and image, including their existing clipping.
    // The bitmap's alpha masks the moving band while the live view stays put.
    target.wantsLayer = YES;
    CALayer *overlay = [CALayer layer];
    overlay.frame = target.layer.bounds;
    CALayer *mask = [CALayer layer];
    mask.frame = overlay.bounds;
    mask.contents = (__bridge id)bitmap.CGImage;
    overlay.mask = mask;

    CAGradientLayer *band = [CAGradientLayer layer];
    CGFloat width = NSWidth(overlay.bounds);
    CGFloat bandWidth = MIN(width, MAX(12, width * 0.58));
    CGFloat start = -bandWidth * 0.39;
    band.frame = NSMakeRect(start, 0, bandWidth, NSHeight(overlay.bounds));
    band.startPoint = CGPointMake(0, 0.5);
    band.endPoint = CGPointMake(1, 0.5);
    [target.effectiveAppearance performAsCurrentDrawingAppearance:^{
        NSColor *light = [NSColor.whiteColor colorWithAlphaComponent:0.88];
        NSColor *dark = [NSColor.blackColor colorWithAlphaComponent:0.49];
        NSColor *clear = NSColor.clearColor;
        if (isTitle) {
            BOOL darkAppearance = [[target.effectiveAppearance bestMatchFromAppearancesWithNames:
                @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
            NSColor *glint = darkAppearance ? [dark colorWithAlphaComponent:0.76] : light;
            band.colors = @[(id)clear.CGColor, (id)glint.CGColor, (id)clear.CGColor];
        } else {
            band.colors = @[(id)clear.CGColor, (id)light.CGColor, (id)dark.CGColor, (id)clear.CGColor];
            band.locations = @[@0, @0.42, @0.69, @1];
        }
    }];
    [overlay addSublayer:band];
    [target.layer addSublayer:overlay];

    CABasicAnimation *sweep = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    sweep.fromValue = @0;
    sweep.toValue = @(width - start);
    sweep.duration = repeating ? 0.68 : 0.64;
    sweep.repeatCount = repeating ? HUGE_VALF : 0;
    sweep.timingFunction = [CAMediaTimingFunction functionWithName:
        repeating ? kCAMediaTimingFunctionEaseOut : kCAMediaTimingFunctionLinear];
    [band addAnimation:sweep forKey:@"tidyTitleSweep"];
    return overlay;
}

static NSArray<CALayer *> *DPTidyTitleSweeps(NSView *row, BOOL repeating) {
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return @[];
    BOOL favorite = DPIsKind(row, DPDiaPinnedTab);
    NSView *content = favorite ? row : DPFindView(row, ^BOOL(NSView *view) {
        return [NSStringFromClass(view.class) hasSuffix:@".TabContentView"] && !view.hiddenOrHasHiddenAncestor;
    });
    NSView *icon = DPTidyTabFavicon(content);
    NSTextField *label = favorite ? nil : DPTidyTabContentTitle(content);
    NSMutableArray<CALayer *> *sweeps = [NSMutableArray new];
    CALayer *iconSweep = DPTidySweep(icon, NO, repeating);
    CALayer *titleSweep = DPTidySweep(label, YES, repeating);
    if (iconSweep) [sweeps addObject:iconSweep];
    if (titleSweep) [sweeps addObject:titleSweep];
    return sweeps;
}

void DPTidyPlayTitleSweep(NSView *row) {
    [CATransaction begin];
    NSArray<CALayer *> *sweeps = DPTidyTitleSweeps(row, NO);
    [CATransaction setCompletionBlock:^{
        for (CALayer *sweep in sweeps) [sweep removeFromSuperlayer];
    }];
    [CATransaction commit];
}

void (^DPTidyShowTitleWaiting(NSView *row))(dispatch_block_t) {
    NSArray<CALayer *> *sweeps = DPTidyTitleSweeps(row, YES);
    return ^(dispatch_block_t next) {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.12];
        [CATransaction setCompletionBlock:^{
            for (CALayer *sweep in sweeps) [sweep removeFromSuperlayer];
        }];
        for (CALayer *sweep in sweeps) sweep.opacity = 0;
        [CATransaction commit];
        next();
    };
}

static CABasicAnimation *DPTidyAnimate(NSString *key, CGFloat from, CGFloat to, CFTimeInterval duration) {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:key];
    animation.fromValue = @(from);
    animation.toValue = @(to);
    animation.duration = duration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    return animation;
}

void DPTidyAnimateTitle(NSTextField *label, NSString *previousTitle) {
    if (!label.window || label.hiddenOrHasHiddenAncestor || !previousTitle.length ||
        NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return;

    label.wantsLayer = YES;
    CALayer *host = label.layer;
    CALayer *parent = host.superlayer;
    if (!parent) return;
    [label.effectiveAppearance performAsCurrentDrawingAppearance:^{
        CATextLayer *outgoing = [CATextLayer layer];
        outgoing.frame = host.frame;
        outgoing.contentsScale = label.window.backingScaleFactor;
        outgoing.truncationMode = kCATruncationEnd;
        outgoing.string = [[NSAttributedString alloc] initWithString:previousTitle attributes:@{
            NSFontAttributeName: label.font ?: [NSFont systemFontOfSize:13],
            NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
            NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)
        }];

        CATextLayer *sparkle = [CATextLayer layer];
        sparkle.string = @"✦";
        sparkle.fontSize = 10;
        sparkle.foregroundColor = NSColor.controlAccentColor.CGColor;
        sparkle.contentsScale = outgoing.contentsScale;
        sparkle.frame = CGRectMake(CGRectGetMaxX(host.frame) - 10, CGRectGetMinY(host.frame), 10, 14);

        CGFloat down = parent.geometryFlipped ? 8 : -8;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        outgoing.opacity = 0;
        sparkle.opacity = 0;
        [parent addSublayer:outgoing];
        [parent addSublayer:sparkle];
        [CATransaction setCompletionBlock:^{
            [outgoing removeFromSuperlayer];
            [sparkle removeFromSuperlayer];
        }];
        // Like Tidy Tabs' separator, group the movement and fade with a soft 300 ms ease.
        CAAnimationGroup *leave = [CAAnimationGroup animation];
        leave.duration = 0.30;
        CABasicAnimation *fall = DPTidyAnimate(@"position.y", 0, down, leave.duration);
        fall.additive = YES;
        leave.animations = @[fall, DPTidyAnimate(@"opacity", 1, 0, leave.duration)];
        [outgoing addAnimation:leave forKey:@"tidyPreviousTitle"];

        CABasicAnimation *rise = DPTidyAnimate(@"position.y", down, 0, 0.30);
        rise.additive = YES;
        [host addAnimation:rise forKey:@"tidyTitleRise"];
        [host addAnimation:DPTidyAnimate(@"opacity", 0, host.opacity, 0.30) forKey:@"tidyTitleFade"];
        [sparkle addAnimation:DPTidyAnimate(@"opacity", 1, 0, 0.50) forKey:@"tidySparkle"];
        [CATransaction commit];
    }];
}
