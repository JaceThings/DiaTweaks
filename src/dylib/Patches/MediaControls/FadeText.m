#import "Views.h"

static const CGFloat DPFadeLength = 18;

// The label is always as wide as its text, so it never redraws while the card animates; a mask cuts it off at the
// view's edge, softly. The mask is a solid part and a gradient, side by side, so its fade keeps its length as the
// view's width animates.
@implementation DPFadeText {
    NSTextField *_label;
    CALayer *_mask, *_solid;
    CAGradientLayer *_fade;
}

- (instancetype)initWithFont:(NSFont *)font color:(NSColor *)color {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    _label = [NSTextField labelWithString:@""];
    _label.font = font;
    _label.textColor = color;
    _label.lineBreakMode = NSLineBreakByClipping;
    [self addSubview:_label];
    _mask = [CALayer layer];
    _solid = [CALayer layer];
    _solid.backgroundColor = NSColor.blackColor.CGColor;
    _fade = [CAGradientLayer layer];
    _fade.colors = @[ (id)NSColor.blackColor.CGColor, (id)NSColor.clearColor.CGColor ];
    _fade.startPoint = CGPointMake(0, 0.5);
    _fade.endPoint = CGPointMake(1, 0.5);
    [_mask addSublayer:_solid];
    [_mask addSublayer:_fade];
    return self;
}

- (void)setString:(NSString *)string {
    if ([_string isEqual:string]) return;
    _string = [string copy];
    _label.stringValue = _string ?: @"";
    self.accessibilityLabel = _string;
    self.needsLayout = YES;
}

- (void)layout {
    [super layout];
    NSRect bounds = self.bounds;
    CGFloat w = NSWidth(bounds), h = NSHeight(bounds), text = ceil(_label.fittingSize.width);
    _label.frame = NSMakeRect(0, 0, text, h);
    CGFloat fade = text > w ? MIN(DPFadeLength, w) : 0;
    DPFollowAnimation(^{
        if (self.layer.mask != self->_mask) self.layer.mask = self->_mask;
        self->_mask.frame = bounds;
        self->_solid.frame = CGRectMake(0, 0, w - fade, h);
        self->_fade.frame = CGRectMake(w - fade, 0, fade, h);
    });
}

@end
