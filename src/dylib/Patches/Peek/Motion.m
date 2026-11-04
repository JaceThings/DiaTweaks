#import "Patches/Peek/Peek.h"

// By default the card opens and closes on the curves an iPhone app opens with, read from iOS 27's SpringBoard in
// github.com/pausedstudio/app-open-teardown (EQUATIONS.md): one critically damped spring with a 0.24 s response moves
// the card, its top and bottom edges spread around it like SpringBoard's rows, the page fades in on SpringBoard's
// crossfade curve, and the page behind dims on its 0.314 s spring. Opening and closing, the card is laid out once at full
// size and only its layer is scaled; expanding resizes it for real.

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

// The card's path between the link and its place. As on iOS, its top and bottom edges each ride their own spring:
// opening, the edge nearest the link is slowest and the far edge fastest, scaled from SpringBoard's row responses by
// how far down the page the link is. Its sides ride the main spring. So the card sweeps out of the link on a curve
// instead of growing along a straight line; closing flips the edges, so the one nearest the link lands first.
static CAKeyframeAnimation *DPPeekTravel(NSRect card, NSRect link, CGFloat linkY, BOOL opening, CFTimeInterval response,
                                         CGFloat dampingRatio, CFTimeInterval *duration) {
    CGFloat ay = 2 * MIN(1, MAX(0, linkY)) - 1, g = ay >= 0 ? ay : 0.75 * ay;
    if (!opening) g = -g;
    // Rows 0 (top) and 2 (bottom): n is 0 and 1 for either sign, so the spread is all there is.
    CFTimeInterval top = response * (1 - 0.5 * g), bottom = response * (1 + 0.5 * g);
    *duration = 0;
    for (NSNumber *r in @[ @(response), @(top), @(bottom) ])
        *duration = MAX(*duration, DPPeekSpring(@"transform", r.doubleValue, dampingRatio).settlingDuration);
    NSRect from = opening ? link : card, to = opening ? card : link;
    NSMutableArray *values = [NSMutableArray new], *times = [NSMutableArray new];
    for (int i = 0; i <= 60; i++) {
        CFTimeInterval t = *duration * i / 60;
        CGFloat side = DPPeekLeft(t, response, dampingRatio), up = DPPeekLeft(t, top, dampingRatio), down = DPPeekLeft(t, bottom, dampingRatio);
        CGFloat minX = NSMinX(to) + (NSMinX(from) - NSMinX(to)) * side, maxX = NSMaxX(to) + (NSMaxX(from) - NSMaxX(to)) * side;
        CGFloat minY = NSMinY(to) + (NSMinY(from) - NSMinY(to)) * up, maxY = NSMaxY(to) + (NSMaxY(from) - NSMaxY(to)) * down;
        [values addObject:[NSValue valueWithCATransform3D:DPPeekSqueeze(card, NSMakeRect(minX, minY, maxX - minX, maxY - minY))]];
        [times addObject:@(i / 60.0)];
    }
    CAKeyframeAnimation *travel = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    travel.values = values;
    travel.keyTimes = times;
    travel.duration = *duration;
    return travel;
}

// Steps a card's growth every frame along the spring until it's settled.
@interface DPPeekGrowth : NSObject
@property (nonatomic, weak) DPPeekCard *peek;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic) CFTimeInterval start, response, duration;
@property (nonatomic) CGFloat dampingRatio;
@property (nonatomic, copy) void (^done)(void);
@end

@implementation DPPeekGrowth
static char DPGrowthKey;

+ (void)grow:(DPPeekCard *)peek response:(CFTimeInterval)response dampingRatio:(CGFloat)dampingRatio done:(void (^)(void))done {
    DPPeekGrowth *growth = [DPPeekGrowth new];
    growth.peek = peek;
    growth.response = response;
    growth.dampingRatio = dampingRatio;
    growth.duration = DPPeekSpring(@"bounds", response, dampingRatio).settlingDuration;
    growth.done = done;
    growth.start = CACurrentMediaTime();
    DPSet(peek, &DPGrowthKey, growth);  // The card keeps it alive; the display link doesn't.
    growth.link = [peek displayLinkWithTarget:growth selector:@selector(step)];
    [growth.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)step {
    DPPeekCard *peek = self.peek;
    CFTimeInterval t = CACurrentMediaTime() - self.start;
    BOOL settled = !peek || t >= self.duration;
    peek.grown = settled ? 1 : 1 - DPPeekLeft(t, self.response, self.dampingRatio);
    peek.needsLayout = YES;
    [peek layoutSubtreeIfNeeded];
    if (!settled) return;
    [self.link invalidate];
    if (self.done) self.done();
    self.done = nil;
    if (peek) DPSet(peek, &DPGrowthKey, nil);
}
@end

@implementation DPPeekCard (Motion)

// Runs the card between the link and its place, and the page behind between clear and dimmed.
- (void)move:(BOOL)opening completion:(void (^)(void))completion {
    // The Settings sliders pick the spring; the dimming keeps iOS's pace relative to it, and never bounces.
    CFTimeInterval response = DPPeekResponse(), duration;
    CGFloat dampingRatio = 1 - DPPeekBounce();
    CAKeyframeAnimation *move = DPPeekTravel(self.cardFrame, self.link, NSMidY(self.link) / MAX(1, NSHeight(self.bounds)), opening,
                                             response, dampingRatio, &duration);
    CASpringAnimation *dim = DPPeekSpring(@"opacity", response * 0.314 / 0.24, 1);
    dim.fromValue = opening ? @0 : @1;
    dim.toValue = opening ? @1 : @0;

    [CATransaction begin];
    [CATransaction setCompletionBlock:completion];
    CAAnimationGroup *card = [CAAnimationGroup animation];
    card.animations = @[move, DPPeekFade(duration, response, dampingRatio, opening)];
    card.duration = duration;
    for (CAAnimation *animation in @[card, dim]) {
        animation.fillMode = kCAFillModeBoth;  // Backwards too, or a frame of the full card can show before it starts.
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
// The card is resized for real each frame, not scaled, so the page lays itself out at each size as it grows.
- (void)animateExpand:(void (^)(void))completion {
    CFTimeInterval response = DPPeekResponse();
    CASpringAnimation *clear = DPPeekSpring(@"opacity", response * 0.314 / 0.24, 1);
    clear.fromValue = @1;
    clear.toValue = @0;
    clear.fillMode = kCAFillModeForwards;
    clear.removedOnCompletion = NO;
    [self.blur.layer addAnimation:clear forKey:@"peek"];
    [DPPeekGrowth grow:self response:response dampingRatio:1 - DPPeekBounce() done:completion];
}

@end
