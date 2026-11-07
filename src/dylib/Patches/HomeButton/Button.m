#import "HomeButton.h"

static const CGFloat DPHouseSize = 12;

// A house outlined like Dia's reload arrow: a roof, two walls and a door, in a 12 pt square, y down.
static CGPathRef DPHousePath(void) {
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 4.75, 11.25);
    CGPathAddLineToPoint(path, NULL, 1.25, 11.25);
    CGPathAddLineToPoint(path, NULL, 1.25, 5);
    CGPathAddLineToPoint(path, NULL, 6, 0.75);
    CGPathAddLineToPoint(path, NULL, 10.75, 5);
    CGPathAddLineToPoint(path, NULL, 10.75, 11.25);
    CGPathAddLineToPoint(path, NULL, 7.25, 11.25);
    CGPathAddLineToPoint(path, NULL, 7.25, 7.75);
    CGPathAddLineToPoint(path, NULL, 4.75, 7.75);
    CGPathCloseSubpath(path);
    return path;
}

// Dia's own colors, read from its buttons in the same toolbar so themes carry over; each is an NSColor ivar.
static NSColor *DPDiaColor(NSView *button, const char *ivar) {
    void **slot = button ? DPIvar(button, ivar) : NULL;
    id color = slot ? (__bridge id)*slot : nil;
    return [color isKindOfClass:NSColor.class] ? color : nil;
}

static NSView *DPSibling(NSView *view, BOOL (^match)(NSView *v)) {
    for (NSView *sub in view.superview.subviews) if (match(sub)) return sub;
    return nil;
}

@implementation DPHomeButtonView {
    CAShapeLayer *_house;
    BOOL _hovered, _pressed;
}

- (instancetype)init {
    if (!(self = [super initWithFrame:NSMakeRect(0, 0, DPHomeSize, DPHomeSize)])) return nil;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 6;
    _house = [CAShapeLayer layer];
    _house.frame = CGRectMake((DPHomeSize - DPHouseSize) / 2, (DPHomeSize - DPHouseSize) / 2, DPHouseSize, DPHouseSize);
    CGPathRef path = DPHousePath();
    _house.path = path;
    CGPathRelease(path);
    _house.fillColor = NULL;
    _house.lineWidth = 1.125;
    _house.lineCap = kCALineCapRound;
    _house.lineJoin = kCALineJoinRound;
    [self.layer addSublayer:_house];
    self.accessibilityLabel = @"Home";
    self.accessibilityRole = NSAccessibilityButtonRole;
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)accessibilityPerformPress { [self goHome]; return YES; }

- (void)goHome {
    DPHideHomeTip();
    if (!DPHomeURL()) return DPShowHomeTip(self, DPHomeTipText());
    DPGoHome(self.window);
}

- (void)restyle {
    NSView *reload = DPSibling(self, ^BOOL(NSView *v) { return strcmp(object_getClassName(v), DPDiaReloadButton) == 0; });
    NSView *hoverable = DPSibling(self, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaHoverableControl); });
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        BOOL dark = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
        NSColor *ink = dark ? NSColor.whiteColor : NSColor.blackColor;
        NSColor *tint = DPDiaColor(reload, "contentTintColor") ?: [ink colorWithAlphaComponent:0.8];
        NSColor *hover = DPDiaColor(hoverable, "hoveredBackgroundColor") ?: [ink colorWithAlphaComponent:dark ? 0.077 : 0.071];
        NSColor *press = DPDiaColor(hoverable, "pressedBackgroundColor") ?: [ink colorWithAlphaComponent:dark ? 0.129 : 0.114];
        NSColor *fill = self->_pressed && self->_hovered ? press : self->_hovered ? hover : NSColor.clearColor;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self->_house.strokeColor = tint.CGColor;
        self.layer.backgroundColor = fill.CGColor;
        [CATransaction commit];
    }];
}

- (void)viewDidMoveToSuperview { [super viewDidMoveToSuperview]; [self restyle]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self restyle]; }
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (!self.window) DPHideHomeTip();
}

- (void)mouseEntered:(NSEvent *)event {
    _hovered = YES;
    [self restyle];
    DPShowHomeTip(self, DPHomeTipText());
}
- (void)mouseExited:(NSEvent *)event {
    _hovered = NO;
    [self restyle];
    DPHideHomeTip();
}
- (void)mouseDown:(NSEvent *)event {
    _pressed = YES;
    [self restyle];
    DPHideHomeTip();
}
- (void)mouseDragged:(NSEvent *)event {
    _hovered = NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds);
    [self restyle];
}
- (void)mouseUp:(NSEvent *)event {
    BOOL inside = NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds);
    _pressed = NO;
    [self restyle];
    if (inside) [self goHome];
}

@end
