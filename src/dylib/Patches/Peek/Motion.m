#import "Patches/Peek/Peek.h"
#import <objc/message.h>

// Springs and row timing follow iOS's app open, from github.com/pausedstudio/app-open-teardown (EQUATIONS.md).

static CASpringAnimation *DPPeekSpring(NSString *keyPath, CFTimeInterval response, CGFloat dampingRatio) {
    CGFloat w = 2 * M_PI / response;
    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:keyPath];
    spring.stiffness = w * w;
    spring.damping = 2 * dampingRatio * w;
    spring.duration = spring.settlingDuration;
    return spring;
}

// 1 at the start, 0 at rest, below 0 while it overshoots.
static CGFloat DPPeekRemaining(CFTimeInterval t, CFTimeInterval response, CGFloat dampingRatio) {
    if (t <= 0) return 1;
    CGFloat w = 2 * M_PI / response;
    if (dampingRatio >= 1) return (1 + w * t) * exp(-w * t);
    CGFloat wd = w * sqrt(1 - dampingRatio * dampingRatio);
    return exp(-dampingRatio * w * t) * (cos(wd * t) + dampingRatio * w / wd * sin(wd * t));
}

// CAMeshTransform is private API, present in QuartzCore since 10.9.
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

// Moves the card between its place and the link as a 3×3 mesh whose rows each ride their own spring (the genie), and
// sets `corners` to keep the on-screen corner radius from 4 pt at the link to the card's own.
static CAAnimationGroup *DPPeekTravel(DPPeekCard *peek, BOOL opening, CAKeyframeAnimation **corners) {
    CFTimeInterval response = DPPeekResponse(), duration = 0, rows[3];
    CGFloat dampingRatio = 1 - DPPeekBounce();
    CGFloat ay = 2 * MIN(1, MAX(0, NSMidY(peek.link) / MAX(1, NSHeight(peek.bounds)))) - 1;
    CGFloat g = !DPPeekGenie() ? 0 : ay >= 0 ? ay : 0.75 * ay;
    if (!opening) g = -g;
    for (int r = 0; r < 3; r++) {
        CGFloat v = r / 2.0, n = g < 0 ? 1 - sqrt(1 - v) : sqrt(v);
        rows[r] = response * (1 - 0.5 * g + g * n);
        duration = MAX(duration, DPPeekSpring(@"meshTransform", rows[r], dampingRatio).settlingDuration);
    }
    // Unit squares: the link within the card, and the card within its view, which has room around it for the shadow.
    NSRect card = peek.cardFrame, outer = peek.card.frame, link = peek.link;
    NSRect source = NSMakeRect((NSMinX(link) - NSMinX(card)) / NSWidth(card), (NSMinY(link) - NSMinY(card)) / NSHeight(card),
                               NSWidth(link) / NSWidth(card), NSHeight(link) / NSHeight(card));
    NSRect inner = NSMakeRect((NSMinX(card) - NSMinX(outer)) / NSWidth(outer), (NSMinY(card) - NSMinY(outer)) / NSHeight(outer),
                              NSWidth(card) / NSWidth(outer), NSHeight(card) / NSHeight(outer));
    CGFloat radius = peek.clip.layer.cornerRadius, largest = MIN(NSWidth(card), NSHeight(card)) / 2;
    BOOL flipped = !peek.card.layer.geometryFlipped;
    NSMutableArray *meshes = [NSMutableArray new], *radii = [NSMutableArray new], *opacities = [NSMutableArray new], *times = [NSMutableArray new];
    int frames = MAX(60, (int)ceil(duration * 120));
    for (int i = 0; i <= frames; i++) {
        CFTimeInterval t = duration * i / frames;
        CGPoint to[9];
        CGFloat away[3];
        for (int r = 0; r < 3; r++) {
            CGFloat remaining = DPPeekRemaining(t, rows[r], dampingRatio);
            away[r] = opening ? remaining : 1 - remaining;
            for (int c = 0; c < 3; c++) {
                CGFloat x = (c / 2.0 - NSMinX(inner)) / NSWidth(inner), y = (r / 2.0 - NSMinY(inner)) / NSHeight(inner);
                CGFloat px = NSMinX(inner) + (x + (NSMinX(source) + x * NSWidth(source) - x) * away[r]) * NSWidth(inner);
                CGFloat py = NSMinY(inner) + (y + (NSMinY(source) + y * NSHeight(source) - y) * away[r]) * NSHeight(inner);
                to[(flipped ? r : 2 - r) * 3 + c] = CGPointMake(px, flipped ? py : 1 - py);
            }
        }
        [meshes addObject:DPMesh(to)];
        CGFloat scale = MIN(1 + (NSWidth(source) - 1) * away[1], 1 + (NSHeight(source) - 1) * away[1]);
        [radii addObject:@(MIN(largest, (radius + (4 - radius) * away[1]) / MAX(0.01, scale)))];
        [opacities addObject:@(MIN(1, MAX(0, (1 - MIN(away[0], MIN(away[1], away[2]))) / 0.02)))];
        [times addObject:@((double)i / frames)];
    }
    CAKeyframeAnimation *mesh = [CAKeyframeAnimation animationWithKeyPath:@"meshTransform"], *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    *corners = [CAKeyframeAnimation animationWithKeyPath:@"cornerRadius"];
    mesh.values = meshes;
    fade.values = opacities;
    (*corners).values = radii;
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[mesh, fade];
    for (CAKeyframeAnimation *keyframes in @[mesh, fade, *corners]) keyframes.keyTimes = times;
    for (CAAnimation *animation in @[mesh, fade, *corners, group]) {
        animation.duration = duration;
        animation.fillMode = kCAFillModeBoth;
        animation.removedOnCompletion = opening;  // Closing holds its end until the card is removed, or it flashes back.
    }
    return group;
}

static CASpringAnimation *DPPeekDim(BOOL dimming) {
    CASpringAnimation *dim = DPPeekSpring(@"opacity", DPPeekResponse() * 0.314 / 0.24, 1);
    dim.fromValue = dimming ? @0 : @1;
    dim.toValue = dimming ? @1 : @0;
    dim.fillMode = kCAFillModeBoth;
    dim.removedOnCompletion = dimming;
    return dim;
}

// Resizes the card for real each frame, so the page re-lays out as it grows rather than stretching.
@interface DPPeekGrowth : NSObject
@property (nonatomic, weak) DPPeekCard *peek;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic) CFTimeInterval start, response, duration;
@property (nonatomic) CGFloat dampingRatio;
@property (nonatomic, copy) void (^done)(void);
@end

@implementation DPPeekGrowth
static char DPGrowthKey;

+ (void)grow:(DPPeekCard *)peek done:(void (^)(void))done {
    DPPeekGrowth *growth = [DPPeekGrowth new];
    growth.peek = peek;
    growth.response = DPPeekResponse();
    growth.dampingRatio = 1 - DPPeekBounce();
    growth.duration = DPPeekSpring(@"bounds", growth.response, growth.dampingRatio).settlingDuration;
    growth.done = done;
    growth.start = CACurrentMediaTime();
    DPSet(peek, &DPGrowthKey, growth);  // The display link doesn't retain it.
    growth.link = [peek displayLinkWithTarget:growth selector:@selector(step)];
    [growth.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)step {
    DPPeekCard *peek = self.peek;
    CFTimeInterval t = CACurrentMediaTime() - self.start;
    BOOL settled = !peek || t >= self.duration;
    peek.grown = settled ? 1 : 1 - DPPeekRemaining(t, self.response, self.dampingRatio);
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

- (void)move:(BOOL)opening {
    CAKeyframeAnimation *corners;
    CAAnimationGroup *travel = DPPeekTravel(self, opening, &corners);
    [CATransaction setDisableActions:YES];
    self.card.alphaValue = 1;
    [self.card.layer addAnimation:travel forKey:@"peek"];
    [self.clip.layer addAnimation:corners forKey:@"peek"];
    [self.shade.layer addAnimation:corners forKey:@"peek"];
}

- (void)animateIn {
    self.controls.alphaValue = self.card.alphaValue = self.blur.alphaValue = 0;
    // Gives the page a moment to paint its first frame, so it's in the card as it opens.
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

- (void)animateOut:(void (^)(void))completion {
    [CATransaction begin];
    [CATransaction setCompletionBlock:completion];
    if (self.card.alphaValue > 0) {  // Not yet shown: closed while waiting for the page to paint.
        [self.blur.layer addAnimation:DPPeekDim(NO) forKey:@"peek"];
        [self move:NO];
    }
    [CATransaction commit];
}

- (void)animateExpand:(void (^)(void))completion {
    self.card.alphaValue = self.blur.alphaValue = 1;
    [self.blur.layer addAnimation:DPPeekDim(NO) forKey:@"peek"];
    [DPPeekGrowth grow:self done:completion];
}

@end
