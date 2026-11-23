#import "Patches/SwipeNewProfile/SwipeNewProfile.h"

static const CGFloat DPBadgeInset = 14, DPGlowWidth = 115;

// Fast at first, settling as it nears the end, like a rubber band.
static CGFloat DPEaseOut(CGFloat t) { return 1 - pow(1 - MIN(1, MAX(0, t)), 2.4); }

static BOOL DPReduceMotion(void) { return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion; }

@implementation DPPullIndicator {
    CALayer *_glow;
    DPPullBadge *_badge;
    CGFloat _shown, _target;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.wantsLayer = YES;
    self.layer.masksToBounds = YES;  // The + comes out from the sidebar's edge, not over the page.
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    // Pinned to the right edge: scaling it sideways widens the bulge with the pull.
    _glow = [CALayer layer];
    _glow.anchorPoint = CGPointMake(1, 0.5);
    _glow.contentsGravity = kCAGravityResize;
    _glow.opacity = 0;
    _badge = [DPPullBadge new];
    [self.layer addSublayer:_glow];
    [self.layer addSublayer:_badge];
    return self;
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)viewDidMoveToWindow { [self updateColors]; }

- (void)viewDidChangeEffectiveAppearance { [self updateColors]; }

- (void)setFrameSize:(NSSize)size {
    BOOL taller = fabs(size.height - NSHeight(self.frame)) > 1;
    [super setFrameSize:size];
    if (taller) [self updateColors];  // The glow is drawn for the sidebar's height.
}

- (void)updateColors {
    if (!self.window) return;
    [_badge colorFor:self.effectiveAppearance scale:self.window.backingScaleFactor];
    _glow.contents = DPEdgeGlow(DPGlowWidth, MAX(1, NSHeight(self.bounds)), self.window.backingScaleFactor, self.effectiveAppearance);
}

// The badge's center: past the right edge at rest, sliding in as the pull grows, and a little further once full.
- (CGPoint)badgeCenterFor:(CGFloat)progress {
    CGFloat size = NSWidth(_badge.bounds), width = NSWidth(self.bounds), out = width + size / 2 + 2, in = width - DPBadgeInset - size / 2;
    if (DPReduceMotion()) return CGPointMake(in, NSMidY(self.bounds));
    CGFloat beyond = progress > 1 ? 6 * (1 - exp(-(progress - 1) * 2)) : 0;
    return CGPointMake(out + (in - out) * DPEaseOut(progress) - beyond, NSMidY(self.bounds));
}

- (void)layoutGlowFor:(CGFloat)progress {
    _glow.bounds = CGRectMake(0, 0, DPGlowWidth, NSHeight(self.bounds));
    _glow.position = CGPointMake(NSWidth(self.bounds), NSMidY(self.bounds));
    CGFloat spread = DPReduceMotion() ? 0.8 : 0.25 + 0.75 * DPEaseOut(progress);
    _glow.transform = CATransform3DMakeScale(spread, 1, 1);
    _glow.opacity = DPEaseOut(progress);
}

- (BOOL)full { return _badge.full; }

- (void)pullTo:(CGFloat)progress {
    _target = MAX(0, progress);
    // Ease toward the pull, hiding uneven samples of Dia's swipe.
    _shown += (_target - _shown) * 0.35;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _badge.position = [self badgeCenterFor:_shown];
    _badge.opacity = MIN(1, _shown * 2.5);
    _badge.fill = _shown;
    [self layoutGlowFor:_shown];
    [CATransaction commit];
    BOOL full = _target >= 1;
    if (full == _badge.full) return;
    _badge.full = full;
    if (!full) return;
    [NSHapticFeedbackManager.defaultPerformer performFeedbackPattern:NSHapticFeedbackPatternAlignment performanceTime:NSHapticFeedbackPerformanceTimeNow];
    if (DPReduceMotion()) return;
    CAKeyframeAnimation *pop = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    pop.values = @[ @1, @1.12, @1 ];
    pop.duration = 0.22;
    pop.timingFunctions = @[ [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut] ];
    [_badge addAnimation:pop forKey:@"pop"];
}

- (void)finish:(BOOL)created {
    // Letting go short eases the + back into the edge instead of snapping it away.
    [CATransaction begin];
    [CATransaction setAnimationDuration:created ? 0.24 : 0.34];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithControlPoints:0.25 :0.9 :0.35 :1]];
    [CATransaction setCompletionBlock:^{ [self removeFromSuperview]; }];
    if (!DPReduceMotion()) {
        if (created) _badge.transform = CATransform3DMakeScale(1.18, 1.18, 1);  // Handing off to Create Profile.
        else _badge.position = [self badgeCenterFor:0];  // Back out the edge it came from.
        [self layoutGlowFor:created ? 1.4 : 0];
    }
    _badge.opacity = 0;
    _glow.opacity = 0;
    [CATransaction commit];
}
@end
