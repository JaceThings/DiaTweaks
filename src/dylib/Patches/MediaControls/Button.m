#import "Views.h"

// A borderless symbol button with a soft square behind it while the pointer is over it, like the sidebar's own. The
// symbol sits in a view of its own, so it can change shape without the square changing with it.
@implementation DPMediaButton {
    NSImageView *_glyph;
    NSImage *_latest;
    NSUInteger _morphs;
    BOOL _hovered;
}

- (instancetype)initWithAction:(void (^)(void))action {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    _handler = [action copy];
    _pointSize = DPSymbolSize;
    _weight = NSFontWeightSemibold;
    self.bordered = NO;
    self.title = @"";
    self.imagePosition = NSNoImage;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 7;
    self.target = self;
    self.action = @selector(run);
    _glyph = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _glyph.imageScaling = NSImageScaleNone;
    _glyph.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _glyph.wantsLayer = YES;
    _glyph.contentTintColor = NSColor.labelColor;
    [self addSubview:_glyph];
    return self;
}

- (void)run { if (self.handler) self.handler(); }
- (NSView *)hitTest:(NSPoint)point { NSView *hit = [super hitTest:point]; return hit == _glyph ? self : hit; }

- (void)setContentTintColor:(NSColor *)color {
    [super setContentTintColor:color];
    _glyph.contentTintColor = color;
}

- (void)setSymbol:(NSString *)symbol label:(NSString *)label { [self setSymbol:symbol label:label animated:NO]; }

// Animated, the old symbol shrinks and blurs, and the new one grows back in sharp.
- (void)setSymbol:(NSString *)symbol label:(NSString *)label animated:(BOOL)animated {
    if ([_symbol isEqual:symbol]) return;
    _symbol = symbol;
    self.accessibilityLabel = label;
    self.toolTip = label;
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:self.pointSize weight:self.weight];
    _latest = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label] imageWithSymbolConfiguration:config];
    NSUInteger morph = ++_morphs;
    if (!animated || !self.window || !_glyph.layer) {
        [_glyph.layer removeAnimationForKey:@"morph"];
        _glyph.image = _latest;
        return;
    }
    DPMorph(_glyph, ^BOOL {
        if (morph != self->_morphs) return NO;  // A newer change took over.
        self->_glyph.image = self->_latest;
        return YES;
    });
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.contentTintColor = enabled ? NSColor.labelColor : NSColor.tertiaryLabelColor;
    [self refresh];
}

- (void)updateTrackingAreas {
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                       options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect
                                                         owner:self
                                                      userInfo:nil]];
    [super updateTrackingAreas];
}

- (void)syncHover {
    NSPoint point = self.window ? [self convertPoint:self.window.mouseLocationOutsideOfEventStream fromView:nil] : NSMakePoint(-1, -1);
    BOOL hovered = self.alphaValue > 0 && NSPointInRect(point, self.bounds);
    if (hovered == _hovered) return;
    _hovered = hovered;
    [self refresh];
}

- (void)mouseEntered:(NSEvent *)event { _hovered = YES; [self refresh]; }
- (void)mouseExited:(NSEvent *)event { _hovered = NO; [self refresh]; }
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)refresh {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.layer.backgroundColor = self->_hovered && self.enabled ? [NSColor.labelColor colorWithAlphaComponent:0.1].CGColor : nil;
    }];
}

- (void)viewDidChangeEffectiveAppearance { [self refresh]; }

@end
