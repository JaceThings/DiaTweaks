#import "Controls.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat DPSwatchSize = 24, DPRestingSize = 16, DPRing = 3;

@interface DPSwatch ()
@property (nonatomic) CGFloat chosen;
@end

@implementation DPSwatch

+ (id)defaultAnimationForKey:(NSAnimatablePropertyKey)key {
    return [key isEqualToString:@"chosen"] ? [CABasicAnimation animation] : [super defaultAnimationForKey:key];
}

- (NSSize)intrinsicContentSize { return NSMakeSize(DPSwatchSize, DPSwatchSize); }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)setChosen:(CGFloat)chosen { _chosen = chosen; self.needsDisplay = YES; }

- (void)setSelected:(BOOL)selected {
    if (_selected == selected && self.window) return;
    _selected = selected;
    if (!self.window) return (void)(self.chosen = selected);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.22;
        context.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.2 :0.9 :0.3 :1];
        self.animator.chosen = selected;
    }];
}

static NSRect DPCentered(NSRect bounds, CGFloat size) {
    return NSMakeRect(NSMidX(bounds) - size / 2, NSMidY(bounds) - size / 2, size, size);
}

- (void)drawRect:(NSRect)dirty {
    CGFloat outer = DPRestingSize + (DPSwatchSize - DPRestingSize) * self.chosen, ring = DPRing * self.chosen;
    if (ring > 0) {
        [NSColor.whiteColor setFill];
        [[NSBezierPath bezierPathWithOvalInRect:DPCentered(self.bounds, outer)] fill];
    }
    NSRect fill = DPCentered(self.bounds, outer - 2 * ring);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:fill];
    [NSGraphicsContext saveGraphicsState];
    [circle addClip];
    if (self.image) {
        NSSize size = self.image.size;
        CGFloat scale = MAX(NSWidth(fill) / size.width, NSHeight(fill) / size.height);
        [self.image drawInRect:NSMakeRect(NSMidX(fill) - size.width * scale / 2, NSMidY(fill) - size.height * scale / 2, size.width * scale, size.height * scale)];
    } else {
        [self.color setFill];
        NSRectFill(fill);
    }
    [NSGraphicsContext restoreGraphicsState];
    if (ring > 0) return;
    [[NSColor colorWithWhite:1 alpha:0.22] setStroke];
    circle = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(fill, 0.25, 0.25)];
    circle.lineWidth = 0.5;
    [circle stroke];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

- (void)mouseEntered:(NSEvent *)event { DPShowTip(self, self.label, nil); }
- (void)mouseExited:(NSEvent *)event { DPHideTip(); }
- (void)mouseDown:(NSEvent *)event { DPHideTip(); }
- (void)mouseUp:(NSEvent *)event {
    if (NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) [self sendAction:self.action to:self.target];
}

@end
