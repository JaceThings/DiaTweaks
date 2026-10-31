#import "LittleDia.h"

static const NSTimeInterval DPLittleLoadPoll = 0.05, DPLittleLoadTimeout = 1, DPLittleLoadStartGrace = 0.4, DPLittleShowWhileLoading = 0.35,
                            DPLittlePaintDelay = 0.08, DPLittleFadeDuration = 0.2;
// A touch under critical damping: it lands quickly with a barely visible settle.
static const CGFloat DPSpringMass = 1, DPSpringStiffness = 240, DPSpringDamping = 27;

@interface DPLittleTransition ()
@property (nonatomic) NSWindow *overlay, *window;
@property (nonatomic) NSString *windowID;
@property (nonatomic) NSURL *url;
@property (nonatomic) BOOL landed, ready;
@end

@implementation DPLittleTransition

static NSMutableSet<DPLittleTransition *> *DPTransitions;

static CASpringAnimation *DPSpring(NSString *keyPath, id from, id to) {
    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:keyPath];
    spring.mass = DPSpringMass;
    spring.stiffness = DPSpringStiffness;
    spring.damping = DPSpringDamping;
    spring.fromValue = from;
    spring.toValue = to;
    spring.duration = spring.settlingDuration;
    return spring;
}

- (instancetype)initFrom:(NSPoint)origin scale:(CGFloat)scale to:(NSRect)frame on:(NSScreen *)screen label:(NSString *)label {
    if (!(self = [super init])) return nil;
    _overlay = [[NSWindow alloc] initWithContentRect:screen.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    _overlay.releasedWhenClosed = NO;
    _overlay.opaque = NO;
    _overlay.backgroundColor = NSColor.clearColor;
    _overlay.hasShadow = NO;
    _overlay.ignoresMouseEvents = YES;
    _overlay.level = NSFloatingWindowLevel;
    _overlay.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorFullScreenAuxiliary;
    NSView *root = _overlay.contentView;
    root.wantsLayer = YES;

    CALayer *card = DPLittleCard(NSOffsetRect(frame, -NSMinX(screen.frame), -NSMinY(screen.frame)), screen, label);
    [root.layer addSublayer:card];

    // A uniform scale keeps the corners and label in proportion, so it reads as the window zooming out.
    NSPoint start = NSMakePoint(origin.x - NSMinX(screen.frame), origin.y - NSMinY(screen.frame));
    CASpringAnimation *move = DPSpring(@"position", [NSValue valueWithPoint:start], [NSValue valueWithPoint:NSPointFromCGPoint(card.position)]);
    CASpringAnimation *grow = DPSpring(@"transform.scale", @(scale), @1);
    CABasicAnimation *appear = [CABasicAnimation animationWithKeyPath:@"opacity"];
    appear.fromValue = @0;
    appear.duration = 0.08;
    [card addAnimation:move forKey:@"move"];
    [card addAnimation:grow forKey:@"grow"];
    [card addAnimation:appear forKey:@"appear"];
    [_overlay orderFrontRegardless];
    [CATransaction flush];

    DPTransitions = DPTransitions ?: [NSMutableSet new];
    [DPTransitions addObject:self];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(move.duration, grow.duration) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.landed = YES;
        [self finish];
    });
    return self;
}

- (void)windowReady:(NSWindow *)window id:(NSString *)windowID url:(NSURL *)url {
    self.window = window;
    self.windowID = windowID;
    self.url = url;
    self.ready = YES;
    [self finish];
}

// Once the card covers the window's final frame, the window is shown under it: Dia doesn't draw pages in a
// transparent window, and revealing one before it has painted shows black.
- (void)finish {
    if (!self.landed || !self.ready) return;
    self.window.alphaValue = 1;
    if (!self.url) {
        [self revealAfterPaint];
        return;
    }
    CFTimeInterval start = CACurrentMediaTime();
    __block CFTimeInterval started = 0;
    NSString *script = [NSString stringWithFormat:@"set t to active tab of window id %@\nreturn {URL of t, loading of t}", DPQuoted(self.windowID)];
    [NSTimer scheduledTimerWithTimeInterval:DPLittleLoadPoll repeats:YES block:^(NSTimer *timer) {
        CFTimeInterval elapsed = CACurrentMediaTime() - start;
        NSAppleEventDescriptor *state = self.window.isVisible ? DPDiaScript(script) : nil;
        BOOL loading = [state descriptorAtIndex:2].booleanValue;
        if (loading && !started) started = CACurrentMediaTime();
        // The tab can report idle before its navigation starts, so idle only counts once it has loaded or had a moment to.
        // A slow page is shown while it's still loading, the way a tab would show it, rather than kept behind the card.
        NSString *current = [state descriptorAtIndex:1].stringValue;
        BOOL navigated = current && ![current isEqualToString:@"about:blank"];
        BOOL loaded = navigated && !loading && (started || elapsed > DPLittleLoadStartGrace);
        BOOL underway = started && CACurrentMediaTime() - started > DPLittleShowWhileLoading;
        if (!loaded && !underway && state && elapsed < DPLittleLoadTimeout) return;
        [timer invalidate];
        [self revealAfterPaint];
    }];
}

- (void)revealAfterPaint {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DPLittlePaintDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = DPLittleFadeDuration;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            self.overlay.animator.alphaValue = 0;
        } completionHandler:^{
            [self.overlay orderOut:nil];
            [DPTransitions removeObject:self];
        }];
    });
}

- (void)cancel {
    [self.overlay orderOut:nil];
    [DPTransitions removeObject:self];
}

@end
