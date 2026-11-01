#import "Peek.h"

void DPPeekAnimate(DPPeekOverlay *overlay, BOOL opening, void (^completion)(void)) {
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        if (completion) completion();
        return;
    }
    CALayer *card = overlay.card.layer, *presented = card.presentationLayer;
    CGFloat scale = 0.02;
    CGPoint smallPosition = CGPointMake(overlay.origin.x - (0.5 - card.anchorPoint.x) * card.bounds.size.width * scale,
                                       overlay.origin.y - (0.5 - card.anchorPoint.y) * card.bounds.size.height * scale);
    CATransform3D smallTransform = CATransform3DMakeScale(scale, scale, 1);
    CABasicAnimation *position = [CABasicAnimation animationWithKeyPath:@"position"];
    position.fromValue = [NSValue valueWithPoint:opening ? smallPosition : (presented ?: card).position];
    position.toValue = [NSValue valueWithPoint:opening ? card.position : smallPosition];
    CABasicAnimation *transform = [CABasicAnimation animationWithKeyPath:@"transform"];
    transform.fromValue = [NSValue valueWithCATransform3D:opening ? smallTransform : (presented ?: card).transform];
    transform.toValue = [NSValue valueWithCATransform3D:opening ? card.transform : smallTransform];
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[position, transform];
    group.duration = 0.25;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    group.fillMode = opening ? kCAFillModeRemoved : kCAFillModeForwards;
    group.removedOnCompletion = opening;
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = opening ? @0 : @((overlay.layer.presentationLayer ?: overlay.layer).opacity);
    fade.toValue = opening ? @1 : @0;
    fade.duration = group.duration;
    fade.timingFunction = group.timingFunction;
    fade.fillMode = opening ? kCAFillModeRemoved : kCAFillModeForwards;
    fade.removedOnCompletion = opening;
    [CATransaction begin];
    [CATransaction setCompletionBlock:completion];
    [card addAnimation:group forKey:@"peekMotion"];
    [overlay.layer addAnimation:fade forKey:@"peekFade"];
    [CATransaction commit];
}
