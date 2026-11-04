#import "Patches/Peek/Peek.h"
#import <objc/message.h>

// The card opens like an iPhone app out of its Home Screen icon, with the curves read from iOS 27's SpringBoard in
// github.com/pausedstudio/app-open-teardown (EQUATIONS.md). One critically damped spring with a 0.24 s response is the
// main clock. The card is a 3×3 mesh whose rows each get their own spring, slowest at the edge nearest the click, so
// the card pulls out of the link rather than just growing. Closing runs the same springs with the rows' order flipped,
// so the edge nearest the link lands first. The card is laid out once at full size, so the page never re-lays out.

static const CFTimeInterval DPPeekResponse = 0.24;  // The main clock: window size, crossfade and corner radius.
static const CGFloat DPPeekRowSpread = 0.5;          // How far the row springs spread around it, for an app.
static const CGFloat DPPeekMeshShare = 0.6;          // How much of the way the mesh rows travel; the clock does the rest.
static const CGFloat DPPeekRadius = 10;              // The card's own corners, as Card.m draws them.

// What's left of a critically damped spring's way, from 1 at the start to 0 at rest.
static CGFloat DPSpring(CFTimeInterval t, CFTimeInterval response) {
    if (t <= 0) return 1;
    CGFloat w = 2 * M_PI / response;
    return (1 + w * t) * exp(-w * t);
}

// kCAMediaTimingFunctionDefault, (0.25, 0.1) (0.25, 1), solved for y at x.
static CGFloat DPEaseDefault(CGFloat x) {
    x = MIN(1, MAX(0, x));
    CGFloat lo = 0, hi = 1, s = 0.5;
    for (int i = 0; i < 40; i++) {
        s = (lo + hi) / 2;
        if (3 * (1 - s) * (1 - s) * s * 0.25 + 3 * (1 - s) * s * s * 0.25 + s * s * s < x) lo = s;
        else hi = s;
    }
    return 3 * (1 - s) * (1 - s) * s * 0.1 + 3 * (1 - s) * s * s + s * s * s;
}

// Rows 0 (top), 1, 2 (bottom) for a click at `y`, 0 at the top of the page and 1 at the bottom. Opening, the row
// nearest the click is slowest; closing negates the amount, so it's fastest.
static void DPRowResponses(CGFloat y, BOOL opening, CFTimeInterval out[3]) {
    CGFloat ay = 2 * MIN(1, MAX(0, y)) - 1, g = ay >= 0 ? ay : 0.75 * ay;
    if (!opening) g = -g;
    for (int r = 0; r < 3; r++) {
        CGFloat v = r / 2.0, n = g < 0 ? 1 - sqrt(1 - v) : sqrt(v);
        out[r] = DPPeekResponse * (1 - DPPeekRowSpread * g + 2 * DPPeekRowSpread * g * n);
    }
}

// Core Animation's mesh transform: private, but in every macOS QuartzCore since 10.9.
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

// One open or close, stepped every frame by the card's display link.
@interface DPPeekMotion : NSObject
@property (nonatomic, weak) DPPeekCard *peek;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic) CFTimeInterval start, duration;
@property (nonatomic) BOOL opening;
@property (nonatomic, copy) void (^done)(void);
@end

@implementation DPPeekMotion {
    CFTimeInterval _rows[3];
    NSRect _source;  // The link, in the card's unit coordinates, y down from the top.
}

static char DPMotionKey;

+ (void)run:(DPPeekCard *)peek opening:(BOOL)opening done:(void (^)(void))done {
    DPPeekMotion *old = DPGet(peek, &DPMotionKey);
    [old.link invalidate];
    DPPeekMotion *motion = [DPPeekMotion new];
    motion.peek = peek;
    motion.opening = opening;
    motion.done = done;
    NSRect card = peek.cardFrame, link = peek.link;
    motion->_source = NSMakeRect((NSMinX(link) - NSMinX(card)) / NSWidth(card), (NSMinY(link) - NSMinY(card)) / NSHeight(card),
                                 NSWidth(link) / NSWidth(card), NSHeight(link) / NSHeight(card));
    DPRowResponses(NSMidY(motion->_source), opening, motion->_rows);
    // iOS ends the transition at about 1.47 times the slowest row's response, and never before 0.4 s.
    motion.duration = MAX(0.40, 1.47 * MAX(motion->_rows[0], MAX(motion->_rows[1], motion->_rows[2])));
    motion.start = CACurrentMediaTime();
    DPSet(peek, &DPMotionKey, motion);
    [motion step];
    motion.link = [peek displayLinkWithTarget:motion selector:@selector(step)];
    [motion.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

// `away` is how far each part is from the full card: 1 at the link, 0 in place.
- (void)step {
    DPPeekCard *peek = self.peek;
    CFTimeInterval t = CACurrentMediaTime() - self.start;
    if (!peek || t >= self.duration) return [self finish];
    CGFloat clock = DPSpring(t, DPPeekResponse), away = self.opening ? clock : 1 - clock;

    // Each vertex goes from the link's corner to the card's, part on the main clock and part on its row's spring.
    CGPoint to[9];
    BOOL flipped = peek.card.layer.geometryFlipped || peek.card.isFlipped;
    for (int r = 0; r < 3; r++) {
        CGFloat row = DPSpring(t, _rows[r]), rowAway = self.opening ? row : 1 - row;
        CGFloat mix = (1 - DPPeekMeshShare) * away + DPPeekMeshShare * rowAway;
        for (int c = 0; c < 3; c++) {
            CGFloat x = c / 2.0, y = r / 2.0;  // y down from the top
            CGFloat sx = NSMinX(_source) + x * NSWidth(_source), sy = NSMinY(_source) + y * NSHeight(_source);
            CGFloat px = x + (sx - x) * mix, py = y + (sy - y) * mix;
            to[(flipped ? r : 2 - r) * 3 + c] = CGPointMake(px, flipped ? py : 1 - py);
        }
    }

    // The page comes in almost at once: fully there by the time a launching icon has faded to 90%.
    CGFloat progress = 1 - away, icon = 1 - DPEaseDefault((progress - 0.15) / 0.45);
    CGFloat alpha = MIN(1, MAX(0, 1 - (icon - 0.9) / 0.1));

    // As on iOS, the corners start as a capsule, which the mesh shrinks with the card, and settle on the card's own.
    CGFloat capsule = MIN(NSWidth(peek.cardFrame), NSHeight(peek.cardFrame)) / 2;
    CGFloat radius = DPPeekRadius + (capsule - DPPeekRadius) * away;

    // The page behind dims on iOS's Home Screen dimming spring: critically damped, 0.314 s.
    CGFloat dim = DPSpring(t, 0.314), shade = self.opening ? 1 - dim : dim;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [peek.card.layer setValue:DPMesh(to) forKey:@"meshTransform"];
    peek.card.layer.opacity = alpha;
    peek.clip.layer.cornerRadius = radius;
    peek.blur.layer.opacity = shade;
    [CATransaction commit];
}

- (void)finish {
    [self.link invalidate];
    self.link = nil;
    DPPeekCard *peek = self.peek;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [peek.card.layer setValue:nil forKey:@"meshTransform"];
    peek.card.layer.opacity = self.opening ? 1 : 0;
    peek.clip.layer.cornerRadius = DPPeekRadius;
    peek.blur.layer.opacity = self.opening ? 1 : 0;
    [CATransaction commit];
    if (self.done) self.done();
    self.done = nil;
}
@end

@implementation DPPeekCard (Motion)

// Out of the link; the controls follow once it's in place.
- (void)animateIn {
    self.controls.alphaValue = 0;
    [DPPeekMotion run:self opening:YES done:^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.12;
            self.controls.animator.alphaValue = 1;
        }];
    }];
}

// Back into the link.
- (void)animateOut:(void (^)(void))completion {
    [DPPeekMotion run:self opening:NO done:completion];
}

@end
