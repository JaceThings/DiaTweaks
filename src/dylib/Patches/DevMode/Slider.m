#import "Controls.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat DPTrackHeight = 10, DPKnob = 18, DPRestingKnob = 8;

@interface DPHueSlider ()
@property (nonatomic) CGFloat shownValue, knobSize;
@property (nonatomic) BOOL dragging;
@end

@implementation DPHueSlider

+ (id)defaultAnimationForKey:(NSAnimatablePropertyKey)key {
    if ([key isEqualToString:@"shownValue"] || [key isEqualToString:@"knobSize"]) return [CABasicAnimation animation];
    return [super defaultAnimationForKey:key];
}

- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric, DPKnob + 4); }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)setShownValue:(CGFloat)shownValue { _shownValue = shownValue; self.needsDisplay = YES; }
- (void)setKnobSize:(CGFloat)knobSize { _knobSize = knobSize; self.needsDisplay = YES; }

- (void)setValue:(CGFloat)value { _value = value; self.shownValue = value; }

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    CGFloat size = selected ? DPKnob : DPRestingKnob;
    if (!self.window) return (void)(self.knobSize = size);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        context.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.2 :0.9 :0.3 :1];
        self.animator.knobSize = size;
    }];
}

- (NSRect)track {
    return NSMakeRect(DPKnob / 2, round((NSHeight(self.bounds) - DPTrackHeight) / 2), NSWidth(self.bounds) - DPKnob, DPTrackHeight);
}

- (void)drawRect:(NSRect)dirty {
    NSRect track = self.track, capsule = NSInsetRect(track, -DPKnob / 2 + 1, 0);
    NSMutableArray *colors = [NSMutableArray new];
    for (int i = 0; i <= 16; i++) [colors addObject:DPHueColor(i / 16.0)];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:capsule xRadius:DPTrackHeight / 2 yRadius:DPTrackHeight / 2];
    [[[NSGradient alloc] initWithColors:colors] drawInBezierPath:path angle:0];
    [[NSColor colorWithWhite:0 alpha:0.1] setStroke];
    path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(capsule, 0.25, 0.25) xRadius:DPTrackHeight / 2 yRadius:DPTrackHeight / 2];
    path.lineWidth = 0.5;
    [path stroke];
    CGFloat size = self.knobSize ?: DPRestingKnob;
    NSRect knob = NSMakeRect(NSMinX(track) + self.shownValue * NSWidth(track) - size / 2, NSMidY(track) - size / 2, size, size);
    NSShadow *shadow = [NSShadow new];
    shadow.shadowOffset = NSMakeSize(0, -1);
    shadow.shadowBlurRadius = 3;
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.3];
    [NSGraphicsContext saveGraphicsState];
    [shadow set];
    [NSColor.whiteColor setFill];
    [[NSBezierPath bezierPathWithOvalInRect:knob] fill];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.openHandCursor]; }

- (void)moveTo:(NSEvent *)event animated:(BOOL)animated {
    NSRect track = self.track;
    CGFloat x = [self convertPoint:event.locationInWindow fromView:nil].x;
    _value = MAX(0, MIN(1, (x - NSMinX(track)) / NSWidth(track)));
    if (!self.selected) self.selected = YES;
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.18;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            self.animator.shownValue = self.value;
        }];
    } else {
        self.shownValue = self.value;
    }
    [self sendAction:self.action to:self.target];
}

- (void)mouseDown:(NSEvent *)event {
    [NSCursor.closedHandCursor push];
    [self moveTo:event animated:YES];
}

- (void)mouseDragged:(NSEvent *)event { [self moveTo:event animated:NO]; }

- (void)mouseUp:(NSEvent *)event {
    [NSCursor pop];
    [self.window invalidateCursorRectsForView:self];
}

@end
