#import "DeveloperMode.h"

@implementation DPDevButton {
    void (^_action)(NSWindow *);
    BOOL _hovered, _pressed;
}

+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label action:(void (^)(NSWindow *window))action {
    DPDevButton *button = [DPDevButton new];
    button->_action = [action copy];
    button.wantsLayer = YES;
    button.layer.cornerRadius = 6;
    button.toolTip = label;
    button.accessibilityRole = NSAccessibilityButtonRole;
    button.accessibilityLabel = label;
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    NSImageView *icon = [NSImageView imageViewWithImage:[image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightRegular]]];
    icon.contentTintColor = NSColor.secondaryLabelColor;
    icon.imageScaling = NSImageScaleNone;
    icon.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [button addSubview:icon];
    return button;
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    self.subviews.firstObject.frame = self.bounds;
}

// The icon would otherwise take the click.
- (NSView *)hitTest:(NSPoint)point {
    return NSPointInRect([self convertPoint:point fromView:self.superview], self.bounds) ? self : nil;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

- (void)refreshBackground {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        CGFloat alpha = _pressed ? 0.2 : _active ? 0.16 : _hovered ? 0.08 : 0;
        self.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:alpha].CGColor;
    }];
}

- (void)setActive:(BOOL)active {
    if (active == _active) return;
    _active = active;
    ((NSImageView *)self.subviews.firstObject).contentTintColor = active ? NSColor.labelColor : NSColor.secondaryLabelColor;
    [self refreshBackground];
}

- (void)viewDidChangeEffectiveAppearance { [self refreshBackground]; }
- (void)mouseEntered:(NSEvent *)event { _hovered = YES; [self refreshBackground]; }
- (void)mouseExited:(NSEvent *)event { _hovered = NO; [self refreshBackground]; }
- (void)mouseDown:(NSEvent *)event { _pressed = YES; [self refreshBackground]; }

- (void)mouseUp:(NSEvent *)event {
    _pressed = NO;
    [self refreshBackground];
    if (NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) _action(self.window);
}

@end
