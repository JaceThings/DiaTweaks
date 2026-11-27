#import "Patches/SwipeNewProfile/SwipeNewProfile.h"

static const CGFloat DPBadgeSize = 36, DPRingWidth = 2.5;

@implementation DPPullBadge {
    CAShapeLayer *_track, *_ring, *_disc;
    CALayer *_plus;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.bounds = CGRectMake(0, 0, DPBadgeSize, DPBadgeSize);
    self.opacity = 0;
    CGPathRef circle = CGPathCreateWithEllipseInRect(CGRectInset(self.bounds, DPRingWidth / 2, DPRingWidth / 2), NULL);
    _disc = [CAShapeLayer layer];
    _disc.path = circle;
    _disc.opacity = 0;
    _track = [CAShapeLayer layer];
    _ring = [CAShapeLayer layer];
    for (CAShapeLayer *line in @[ _track, _ring ]) {
        line.path = circle;
        line.fillColor = nil;
        line.lineWidth = DPRingWidth;
        line.frame = self.bounds;
    }
    CGPathRelease(circle);
    _ring.lineCap = kCALineCapRound;
    _ring.strokeEnd = 0;
    // Start the ring at the top and run it counterclockwise, as Arc's does.
    _ring.affineTransform = CGAffineTransformMakeRotation(M_PI_2);
    _plus = [CALayer layer];
    _plus.frame = self.bounds;
    _plus.contentsGravity = kCAGravityCenter;
    for (CALayer *layer in @[ _disc, _track, _ring, _plus ]) [self addSublayer:layer];
    return self;
}

- (void)colorFor:(NSAppearance *)appearance scale:(CGFloat)scale {
    [appearance performAsCurrentDrawingAppearance:^{
        NSColor *ink = NSColor.labelColor;
        self->_track.strokeColor = NSColor.tertiaryLabelColor.CGColor;
        self->_ring.strokeColor = ink.CGColor;
        self->_disc.fillColor = [ink colorWithAlphaComponent:0.14].CGColor;
        NSImageSymbolConfiguration *config = [[NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightSemibold]
            configurationByApplyingConfiguration:[NSImageSymbolConfiguration configurationWithHierarchicalColor:ink]];
        self->_plus.contents = [[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:nil] imageWithSymbolConfiguration:config];
        self->_plus.contentsScale = scale;
    }];
}

- (void)setFill:(CGFloat)fill {
    _fill = fill;
    _ring.strokeEnd = MIN(1, MAX(0, fill));
}

- (void)setFull:(BOOL)full {
    _full = full;
    _disc.opacity = full ? 1 : 0;
}
@end
