#import "Patches/Peek/Peek.h"

// By default the card opens and closes on the curves an iPhone app opens with, read from iOS 27's SpringBoard in
// github.com/pausedstudio/app-open-teardown (EQUATIONS.md): one critically damped spring with a 0.24 s response moves
// the card, the page fades in on SpringBoard's crossfade curve, and the page behind dims on its 0.314 s spring. The
// card is laid out once at full size and only its layer is scaled, so the page never re-lays out mid-animation.

// A spring of unit mass from rest, as SpringBoard describes them: a response in seconds and a damping ratio.
static CASpringAnimation *DPPeekSpring(NSString *keyPath, CFTimeInterval response, CGFloat dampingRatio) {
    CGFloat w = 2 * M_PI / response;
    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:keyPath];
    spring.mass = 1;
    spring.stiffness = w * w;
    spring.damping = 2 * dampingRatio * w;
    spring.duration = spring.settlingDuration;
    return spring;
}

// What's left of a spring's way at `t`, from 1 at the start to 0 at rest, overshooting below 0 when it bounces.
static CGFloat DPPeekLeft(CFTimeInterval t, CFTimeInterval response, CGFloat dampingRatio) {
    if (t <= 0) return 1;
    CGFloat w = 2 * M_PI / response;
    if (dampingRatio >= 1) return (1 + w * t) * exp(-w * t);
    CGFloat wd = w * sqrt(1 - dampingRatio * dampingRatio);
    return exp(-dampingRatio * w * t) * (cos(wd * t) + dampingRatio * w / wd * sin(wd * t));
}

// kCAMediaTimingFunctionDefault, (0.25, 0.1) (0.25, 1), solved for y at x.
static CGFloat DPPeekEaseDefault(CGFloat x) {
    x = MIN(1, MAX(0, x));
    CGFloat lo = 0, hi = 1, s = 0.5;
    for (int i = 0; i < 40; i++) {
        s = (lo + hi) / 2;
        if (3 * (1 - s) * (1 - s) * s * 0.25 + 3 * (1 - s) * s * s * 0.25 + s * s * s < x) lo = s;
        else hi = s;
    }
    return 3 * (1 - s) * (1 - s) * s * 0.1 + 3 * (1 - s) * s * s + s * s * s;
}

// The card's opacity over the main spring. SpringBoard has the app fully in by the time its icon has faded to 90%;
// closing plays it backwards, so the card stays solid until it's nearly back in the link.
static CAKeyframeAnimation *DPPeekFade(CFTimeInterval duration, CFTimeInterval response, CGFloat dampingRatio, BOOL opening) {
    NSMutableArray *values = [NSMutableArray new], *times = [NSMutableArray new];
    for (int i = 0; i <= 30; i++) {
        CFTimeInterval t = duration * i / 30;
        CGFloat progress = 1 - DPPeekLeft(t, response, dampingRatio);
        if (!opening) progress = 1 - progress;
        CGFloat icon = 1 - DPPeekEaseDefault((progress - 0.15) / 0.45);
        [values addObject:@(MIN(1, MAX(0, 1 - (icon - 0.9) / 0.1)))];
        [times addObject:@(i / 30.0)];
    }
    CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    fade.values = values;
    fade.keyTimes = times;
    fade.duration = duration;
    return fade;
}

// Draws the card, laid out at `card`, squeezed into `rect`. A layer-backed view's layer scales about its origin, which
// is the card's top left in this flipped view.
static CATransform3D DPPeekSqueeze(NSRect card, NSRect rect) {
    CATransform3D scale = CATransform3DMakeScale(NSWidth(rect) / MAX(1, NSWidth(card)), NSHeight(rect) / MAX(1, NSHeight(card)), 1);
    return CATransform3DConcat(scale, CATransform3DMakeTranslation(NSMinX(rect) - NSMinX(card), NSMinY(rect) - NSMinY(card), 0));
}

@implementation DPPeekCard (Motion)

// Runs the card between the link and its place, and the page behind between clear and dimmed.
- (void)move:(BOOL)opening completion:(void (^)(void))completion {
    NSValue *squeezed = [NSValue valueWithCATransform3D:DPPeekSqueeze(self.cardFrame, self.link)];
    NSValue *inPlace = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    // The Settings sliders pick the spring; the dimming keeps iOS's pace relative to it, and never bounces.
    CFTimeInterval response = DPPeekResponse();
    CGFloat dampingRatio = 1 - DPPeekBounce();
    CASpringAnimation *move = DPPeekSpring(@"transform", response, dampingRatio);
    move.fromValue = opening ? squeezed : inPlace;
    move.toValue = opening ? inPlace : squeezed;
    CASpringAnimation *dim = DPPeekSpring(@"opacity", response * 0.314 / 0.24, 1);
    dim.fromValue = opening ? @0 : @1;
    dim.toValue = opening ? @1 : @0;

    [CATransaction begin];
    [CATransaction setCompletionBlock:completion];
    CAAnimationGroup *card = [CAAnimationGroup animation];
    card.animations = @[move, DPPeekFade(move.duration, response, dampingRatio, opening)];
    card.duration = move.duration;
    for (CAAnimation *animation in @[card, dim]) {
        animation.fillMode = kCAFillModeForwards;
        animation.removedOnCompletion = opening;  // Closing holds the end, so nothing flashes before the card goes.
    }
    [self.card.layer addAnimation:card forKey:@"peek"];
    [self.blur.layer addAnimation:dim forKey:@"peek"];
    [CATransaction commit];
}

// Out of the link; the controls follow once it's in place.
- (void)animateIn {
    self.controls.alphaValue = 0;
    [self move:YES completion:^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.12;
            self.controls.animator.alphaValue = 1;
        }];
    }];
}

// Back into the link.
- (void)animateOut:(void (^)(void))completion {
    [self move:NO completion:completion];
}

// Out to fill the whole page area on the same spring, with the page behind clearing, before it becomes a tab there.
// The end holds, so the card stays full size until the tab takes its place.
- (void)animateExpand:(void (^)(void))completion {
    CFTimeInterval response = DPPeekResponse();
    CASpringAnimation *fill = DPPeekSpring(@"transform", response, 1 - DPPeekBounce());
    fill.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    fill.toValue = [NSValue valueWithCATransform3D:DPPeekSqueeze(self.cardFrame, self.bounds)];
    CASpringAnimation *clear = DPPeekSpring(@"opacity", response * 0.314 / 0.24, 1);
    clear.fromValue = @1;
    clear.toValue = @0;

    [CATransaction begin];
    [CATransaction setCompletionBlock:completion];
    for (CAAnimation *animation in @[fill, clear]) {
        animation.fillMode = kCAFillModeForwards;
        animation.removedOnCompletion = NO;
    }
    [self.card.layer addAnimation:fill forKey:@"peek"];
    [self.blur.layer addAnimation:clear forKey:@"peek"];
    [CATransaction commit];
}

@end
