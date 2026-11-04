#import "Patches/Peek/Peek.h"
#import <objc/message.h>

// By default the card opens and closes on the curves an iPhone app opens with, read from iOS 27's SpringBoard in
// github.com/pausedstudio/app-open-teardown (EQUATIONS.md): one critically damped spring with a 0.24 s response moves
// the card, its rows of vertices spread around it like SpringBoard's, the page fades in on SpringBoard's
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

// The card's opacity over the main spring. SpringBoard has the app fully in by the time its icon has faded to 90%, but
// there the icon covers the start; a peek has no icon, so opening it shows straight away at the link's size and shape.
// Closing plays SpringBoard's crossfade backwards, so the card stays solid until it's nearly back in the link.
static CAKeyframeAnimation *DPPeekFade(CFTimeInterval duration, CFTimeInterval response, CGFloat dampingRatio, BOOL opening) {
    NSMutableArray *values = [NSMutableArray new], *times = [NSMutableArray new];
    for (int i = 0; i <= 30; i++) {
        CFTimeInterval t = duration * i / 30;
        CGFloat progress = 1 - DPPeekLeft(t, response, dampingRatio);
        if (!opening) progress = 1 - progress;
        CGFloat icon = 1 - DPPeekEaseDefault((progress - 0.15) / 0.45);
        [values addObject:@(opening ? MIN(1, progress / 0.02) : MIN(1, MAX(0, 1 - (icon - 0.9) / 0.1)))];
        [times addObject:@(i / 30.0)];
    }
    CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    fade.values = values;
    fade.keyTimes = times;
    fade.duration = duration;
    return fade;
}

// Core Animation's mesh transform: private, but in every macOS QuartzCore since 10.9. A 3×3 grid of vertices, each
// moved from its spot in the layer's unit square to `to`.
typedef struct { CGFloat x, y, z; } DPPoint3D;
typedef struct { CGPoint from; DPPoint3D to; } DPMeshVertex;
typedef struct { unsigned int indices[4]; float w[4]; } DPMeshFace;

static id DPMesh(const CGPoint to[9]) {
    DPMeshVertex vertices[9];
    for (int i = 0; i < 9; i++) vertices[i] = (DPMeshVertex){{(i % 3) / 2.0, (i / 3) / 2.0}, {to[i].x, to[i].y, 0}};
    DPMeshFace faces[4];
    for (int f = 0; f < 4; f++) {
        unsigned int i = (f / 2) * 3 + f % 2;
        faces[f] = (DPMeshFace){{i, i + 1, i + 4, i + 3}, {0, 0, 0, 0}};
    }
    id (*make)(Class, SEL, NSUInteger, DPMeshVertex *, NSUInteger, DPMeshFace *, NSString *) = (void *)objc_msgSend;
    return make(NSClassFromString(@"CAMeshTransform"), NSSelectorFromString(@"meshTransformWithVertexCount:vertices:faceCount:faces:depthNormalization:"),
                9, vertices, 4, faces, @"none");
}

// The card's path between the link and its place, as iOS opens an app out of its icon: the card is a 3×3 mesh, and
// each row of vertices rides its own spring, scaled from SpringBoard's row responses by how far down the page the link
// is. Opening, the row nearest the link is slowest and the far row fastest, so the card's sides bend as it pulls out
// of the link; closing flips them, so the row nearest the link lands first. With the genie effect off, every row rides
// the same spring, so the card keeps its shape and just grows out of the link. The mesh covers the card's shadow too,
// so the shadow shrinks and grows with it, and `corners` keeps the card's corners from shrinking to square on the way:
// they go from 4 pt at the link to the card's own radius.
static CAKeyframeAnimation *DPPeekTravel(DPPeekCard *peek, BOOL opening, CFTimeInterval response, CGFloat dampingRatio,
                                         CFTimeInterval *duration, CAKeyframeAnimation **corners) {
    CGFloat linkY = NSMidY(peek.link) / MAX(1, NSHeight(peek.bounds));
    CGFloat ay = 2 * MIN(1, MAX(0, linkY)) - 1, g = !DPPeekGenie() ? 0 : ay >= 0 ? ay : 0.75 * ay;
    if (!opening) g = -g;
    CFTimeInterval rows[3];
    *duration = 0;
    for (int r = 0; r < 3; r++) {
        CGFloat v = r / 2.0, n = g < 0 ? 1 - sqrt(1 - v) : sqrt(v);
        rows[r] = response * (1 - 0.5 * g + g * n);
        *duration = MAX(*duration, DPPeekSpring(@"meshTransform", rows[r], dampingRatio).settlingDuration);
    }
    // The link in the card's unit square, y down from the top, and the card in the unit square of the layer that holds
    // it and its shadow.
    NSRect card = peek.cardFrame, outer = peek.card.frame, link = peek.link;
    NSRect source = NSMakeRect((NSMinX(link) - NSMinX(card)) / NSWidth(card), (NSMinY(link) - NSMinY(card)) / NSHeight(card),
                               NSWidth(link) / NSWidth(card), NSHeight(link) / NSHeight(card));
    NSRect inner = NSMakeRect((NSMinX(card) - NSMinX(outer)) / NSWidth(outer), (NSMinY(card) - NSMinY(outer)) / NSHeight(outer),
                              NSWidth(card) / NSWidth(outer), NSHeight(card) / NSHeight(outer));
    CGFloat radius = peek.clip.layer.cornerRadius, largest = MIN(NSWidth(card), NSHeight(card)) / 2;
    BOOL flipped = !peek.card.layer.geometryFlipped;
    NSMutableArray *values = [NSMutableArray new], *radii = [NSMutableArray new], *times = [NSMutableArray new];
    for (int i = 0; i <= 60; i++) {
        CFTimeInterval t = *duration * i / 60;
        CGPoint to[9];
        CGFloat aways[3];
        for (int r = 0; r < 3; r++) {
            CGFloat left = DPPeekLeft(t, rows[r], dampingRatio), away = aways[r] = opening ? left : 1 - left;
            for (int c = 0; c < 3; c++) {
                // Each vertex in the card's own unit square, moved toward the link, then back into the outer square.
                CGFloat x = (c / 2.0 - NSMinX(inner)) / NSWidth(inner), y = (r / 2.0 - NSMinY(inner)) / NSHeight(inner);
                CGFloat px = x + (NSMinX(source) + x * NSWidth(source) - x) * away, py = y + (NSMinY(source) + y * NSHeight(source) - y) * away;
                px = NSMinX(inner) + px * NSWidth(inner);
                py = NSMinY(inner) + py * NSHeight(inner);
                to[(flipped ? r : 2 - r) * 3 + c] = CGPointMake(px, flipped ? py : 1 - py);
            }
        }
        [values addObject:DPMesh(to)];
        // The radius the mesh shrinks to the target on screen, from the middle row's scale; the shorter side decides.
        CGFloat a = aways[1], scale = MIN(1 + (NSWidth(source) - 1) * a, 1 + (NSHeight(source) - 1) * a);
        [radii addObject:@(MIN(largest, (radius + (4 - radius) * a) / MAX(0.01, scale)))];
        [times addObject:@(i / 60.0)];
    }
    CAKeyframeAnimation *travel = [CAKeyframeAnimation animationWithKeyPath:@"meshTransform"];
    travel.values = values;
    *corners = [CAKeyframeAnimation animationWithKeyPath:@"cornerRadius"];
    (*corners).values = radii;
    for (CAKeyframeAnimation *animation in @[travel, *corners]) {
        animation.keyTimes = times;
        animation.duration = *duration;
        animation.fillMode = kCAFillModeBoth;  // Backwards too, or a frame of the full card can show before it starts.
        animation.removedOnCompletion = opening;  // Closing holds the end, so nothing flashes before the card goes.
    }
    return travel;
}

// The page behind dimming or clearing on SpringBoard's 0.314 s spring, kept at the card's pace; it never bounces.
static CASpringAnimation *DPPeekDim(BOOL dimming) {
    CASpringAnimation *dim = DPPeekSpring(@"opacity", DPPeekResponse() * 0.314 / 0.24, 1);
    dim.fromValue = dimming ? @0 : @1;
    dim.toValue = dimming ? @1 : @0;
    dim.fillMode = kCAFillModeBoth;
    dim.removedOnCompletion = dimming;  // Clearing holds the end, so the page behind doesn't flash dark as the card goes.
    return dim;
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

// Runs the card between the link and its place.
- (void)move:(BOOL)opening {
    CFTimeInterval response = DPPeekResponse(), duration;
    CGFloat dampingRatio = 1 - DPPeekBounce();
    CAKeyframeAnimation *corners, *move = DPPeekTravel(self, opening, response, dampingRatio, &duration, &corners);
    CAAnimationGroup *card = [CAAnimationGroup animation];
    card.animations = @[move, DPPeekFade(duration, response, dampingRatio, opening)];
    card.duration = duration;
    card.fillMode = move.fillMode;
    card.removedOnCompletion = move.removedOnCompletion;
    [CATransaction setDisableActions:YES];
    self.card.alphaValue = 1;
    [self.card.layer addAnimation:card forKey:@"peek"];
    [self.clip.layer addAnimation:corners forKey:@"peek"];
    [self.shade.layer addAnimation:corners forKey:@"peek"];
}

// Out of the link; the controls follow once it's in place.
- (void)animateIn {
    self.controls.alphaValue = 0;
    self.card.alphaValue = 0;  // Still drawing, just unseen, so the page paints its first frame meanwhile.
    self.blur.alphaValue = 0;  // The page behind dims as the card opens, not before.
    // The card waits a moment for the page's first paint, so a quick page is in it as it opens and not a blank. A slow one
    // (most sites take about half a second) isn't worth a lag on every click, so it fills in after the card is open.
    CFTimeInterval start = CACurrentMediaTime();
    __weak DPPeekCard *weak = self;
    [NSTimer scheduledTimerWithTimeInterval:1 / 120.0 repeats:YES block:^(NSTimer *timer) {
        DPPeekCard *peek = weak;
        if (!peek || peek.closing) return [timer invalidate];
        if (![[(NSObject *)peek.page valueForKey:@"isReadyToDisplay"] boolValue] && CACurrentMediaTime() - start < 0.15) return;
        [timer invalidate];
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.12;
                peek.controls.animator.alphaValue = 1;
            }];
        }];
        [peek move:YES];
        peek.blur.alphaValue = 1;
        [peek.blur.layer addAnimation:DPPeekDim(YES) forKey:@"peek"];
        [CATransaction commit];
    }];
}

// Back into the link.
- (void)animateOut:(void (^)(void))completion {
    [CATransaction begin];
    [CATransaction setCompletionBlock:completion];
    if (self.card.alphaValue > 0) {  // A card closed before it opened has nowhere to go back from.
        [self.blur.layer addAnimation:DPPeekDim(NO) forKey:@"peek"];
        [self move:NO];
    }
    [CATransaction commit];
}

// Out to fill the whole page area on the same spring, with the page behind clearing, before it becomes a tab there.
// The card is resized for real each frame, not scaled, so the page lays itself out at each size as it grows.
- (void)animateExpand:(void (^)(void))completion {
    self.card.alphaValue = self.blur.alphaValue = 1;
    [self.blur.layer addAnimation:DPPeekDim(NO) forKey:@"peek"];
    [DPPeekGrowth grow:self response:DPPeekResponse() dampingRatio:1 - DPPeekBounce() done:completion];
}

@end
