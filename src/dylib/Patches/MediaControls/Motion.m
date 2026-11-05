#import "Views.h"
#import <CoreImage/CoreImage.h>

// The whole card moves on one curve, and the layers the views don't own (the text fades) follow the same one.
void DPAnimate(void (^changes)(void)) {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPOpenDuration;
        context.allowsImplicitAnimation = YES;
        context.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.2 :0.8 :0.2 :1];  // Moves at once, settles softly.
        changes();
    }];
}

void DPFollowAnimation(void (^changes)(void)) {
    NSAnimationContext *context = NSAnimationContext.currentContext;
    [CATransaction begin];
    if (context.allowsImplicitAnimation) {
        [CATransaction setAnimationDuration:context.duration];
        [CATransaction setAnimationTimingFunction:context.timingFunction];
    } else {
        [CATransaction setDisableActions:YES];
    }
    changes();
    [CATransaction commit];
}

// 0 is the view as it is; 1 is 0.7 of its size about its centre, blurred and a little faded.
static CAAnimation *DPMorphStep(NSView *view, CGFloat from, CGFloat to, NSTimeInterval duration, CAMediaTimingFunction *curve) {
    CGPoint c = CGPointMake(NSMidX(view.bounds), NSMidY(view.bounds));
    NSValue * (^scale)(CGFloat) = ^(CGFloat p) {
        CGFloat s = 1 - 0.3 * p;
        return [NSValue valueWithCATransform3D:CATransform3DTranslate(CATransform3DScale(CATransform3DMakeTranslation(c.x, c.y, 0), s, s, 1), -c.x, -c.y, 0)];
    };
    CABasicAnimation *transform = [CABasicAnimation animationWithKeyPath:@"transform"], *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    CABasicAnimation *blur = [CABasicAnimation animationWithKeyPath:@"filters.blur.inputRadius"];
    transform.fromValue = scale(from), transform.toValue = scale(to);
    opacity.fromValue = @(1 - 0.4 * from), opacity.toValue = @(1 - 0.4 * to);
    blur.fromValue = @(2 * from), blur.toValue = @(2 * to);
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[ transform, opacity, blur ];
    group.duration = duration;
    group.timingFunction = curve;
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = to == 0;  // Held while small, until the way back replaces it.
    return group;
}

void DPMorph(NSView *view, BOOL (^swap)(void)) {
    if (!view.layer) {
        swap();
        return;
    }
    view.layerUsesCoreImageFilters = YES;
    if (!view.contentFilters.count) {
        CIFilter *blur = [NSClassFromString(@"CIFilter") filterWithName:@"CIGaussianBlur"];
        blur.name = @"blur";
        [blur setValue:@0 forKey:@"inputRadius"];
        if (blur) view.contentFilters = @[ blur ];
    }
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        if (swap()) [view.layer addAnimation:DPMorphStep(view, 1, 0, 0.16, [CAMediaTimingFunction functionWithControlPoints:0.2 :0.8 :0.2 :1]) forKey:@"morph"];
    }];
    [view.layer addAnimation:DPMorphStep(view, 0, 1, 0.1, [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]) forKey:@"morph"];
    [CATransaction commit];
}
