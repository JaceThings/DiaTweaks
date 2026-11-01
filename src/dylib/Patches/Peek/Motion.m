#import "Patches/Peek/Peek.h"

// Timed from screen recordings of Arc: about 0.15 s each way, moving straight away and slowing into place. The card is
// laid out once at full size and only its layer is scaled, so the page never re-lays out mid-animation.
static const CFTimeInterval DPPeekGrow = 0.16, DPPeekShrink = 0.15;

static CAMediaTimingFunction *DPPeekEase(void) { return [CAMediaTimingFunction functionWithControlPoints:0.2 :0.9 :0.25 :1]; }

// Draws the card, laid out at `card`, squeezed into `rect`. A layer-backed view's layer scales about its origin, which
// is the card's top left in this flipped view.
static CATransform3D DPPeekSqueeze(NSRect card, NSRect rect) {
    CATransform3D scale = CATransform3DMakeScale(NSWidth(rect) / MAX(1, NSWidth(card)), NSHeight(rect) / MAX(1, NSHeight(card)), 1);
    return CATransform3DConcat(scale, CATransform3DMakeTranslation(NSMinX(rect) - NSMinX(card), NSMinY(rect) - NSMinY(card), 0));
}

@implementation DPPeekCard (Motion)

// Out of the link, the page fading in over the first part; the controls follow once it's in place.
- (void)animateIn {
    CABasicAnimation *grow = [CABasicAnimation animationWithKeyPath:@"transform"];
    grow.fromValue = [NSValue valueWithCATransform3D:DPPeekSqueeze(self.cardFrame, self.link)];
    grow.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    CABasicAnimation *appear = [CABasicAnimation animationWithKeyPath:@"opacity"];
    appear.fromValue = @0;
    appear.toValue = @1;
    appear.duration = DPPeekGrow * 0.35;
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[grow, appear];
    group.duration = DPPeekGrow;
    group.timingFunction = DPPeekEase();
    [self.card.layer addAnimation:group forKey:@"peek"];
    CABasicAnimation *blur = [CABasicAnimation animationWithKeyPath:@"opacity"];
    blur.fromValue = @0;
    blur.duration = DPPeekGrow;
    [self.blur.layer addAnimation:blur forKey:@"peek"];
    self.controls.alphaValue = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DPPeekGrow * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.12;
            self.controls.animator.alphaValue = 1;
        }];
    });
}

// Back into the link, solid for the first half and fading into the page as it lands.
- (void)animateOut:(void (^)(void))completion {
    [CATransaction begin];
    [CATransaction setCompletionBlock:completion];
    CABasicAnimation *shrink = [CABasicAnimation animationWithKeyPath:@"transform"];
    shrink.toValue = [NSValue valueWithCATransform3D:DPPeekSqueeze(self.cardFrame, self.link)];
    shrink.timingFunction = DPPeekEase();
    CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    fade.values = @[@1, @1, @0];
    fade.keyTimes = @[@0, @0.5, @1];
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[shrink, fade];
    group.duration = DPPeekShrink;
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    [self.card.layer addAnimation:group forKey:@"peek"];
    CABasicAnimation *clear = [CABasicAnimation animationWithKeyPath:@"opacity"];
    clear.toValue = @0;
    clear.duration = DPPeekShrink;
    clear.fillMode = kCAFillModeForwards;
    clear.removedOnCompletion = NO;
    [self.blur.layer addAnimation:clear forKey:@"peek"];
    [CATransaction commit];
}

@end
