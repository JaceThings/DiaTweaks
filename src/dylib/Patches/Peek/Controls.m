#import "Patches/Peek/Peek.h"

static const CGFloat DPHintHeight = 26, DPHintPadX = 10, DPHintPadY = 5, DPHintLabelGap = 6, DPHintCapGap = 4, DPHintRightGap = 10;

@interface DPPeekButton : NSButton
@property (nonatomic, weak) NSView *pill;
@property (nonatomic, copy) NSString *hintText;
@property (nonatomic, copy) NSArray<NSString *> *hintKeys;
@property (nonatomic, strong) CAShapeLayer *circle;
@property (nonatomic, strong) CALayer *iconLayer;
@end

@implementation DPPeekButton
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)layout {
    [super layout];
    self.circle.frame = self.bounds;
    CGPathRef path = CGPathCreateWithEllipseInRect(self.bounds, NULL);
    self.circle.path = path;
    CGPathRelease(path);
    self.iconLayer.position = CGPointMake(NSMidX(self.bounds), NSMidY(self.bounds));
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.circle.fillColor = [NSColor colorWithWhite:0.08 alpha:highlighted ? 0.7 : 0.9].CGColor;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
                                                       options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                         owner:self userInfo:nil]];
}

- (void)grow:(BOOL)hovered {
    CGFloat scale = 1.12, cx = NSWidth(self.bounds) / 2, cy = NSHeight(self.bounds) / 2;
    CATransform3D grown = CATransform3DTranslate(CATransform3DScale(CATransform3DMakeTranslation(cx, cy, 0), scale, scale, 1), -cx, -cy, 0);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.12;
        context.allowsImplicitAnimation = YES;
        self.layer.transform = hovered ? grown : CATransform3DIdentity;
    }];
}

- (void)showHint {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.12;
        self.pill.animator.alphaValue = 1;
    }];
}

- (void)mouseEntered:(NSEvent *)event {
    [self grow:YES];
    [self performSelector:@selector(showHint) withObject:nil afterDelay:1.0];
}

- (void)mouseExited:(NSEvent *)event {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showHint) object:nil];
    [self grow:NO];
    self.pill.alphaValue = 0;
}
@end

static NSView *DPPeekKeycap(NSString *glyph) {
    static const CGFloat height = 17;
    NSTextField *label = [NSTextField labelWithString:glyph];
    label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    label.textColor = [NSColor colorWithWhite:0.08 alpha:1];
    label.alignment = NSTextAlignmentCenter;
    [label sizeToFit];
    CGFloat width = MAX(height, NSWidth(label.frame) + 8);
    NSView *cap = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
    cap.wantsLayer = YES;
    cap.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.95].CGColor;
    cap.layer.cornerRadius = 4;
    cap.layer.cornerCurve = kCACornerCurveContinuous;
    label.frame = NSMakeRect(0, (height - NSHeight(label.frame)) / 2, width, NSHeight(label.frame));
    [cap addSubview:label];
    return cap;
}

static NSSize DPPeekFit(NSTextField *label, CGFloat width) {
    NSSize size = [label.cell cellSizeForBounds:NSMakeRect(0, 0, width, 10000)];
    return NSMakeSize(ceil(size.width), ceil(size.height));
}

// A pill with the label and its keycaps in a row, or with the keycaps centred under the label when the row won't fit.
static NSView *DPPeekMakeHint(NSString *text, NSArray<NSString *> *keys, CGFloat maxWidth) {
    NSMutableArray<NSView *> *caps = [NSMutableArray array];
    CGFloat capsWidth = keys.count ? -DPHintCapGap : 0, capsHeight = 0;
    for (NSString *key in keys) {
        NSView *cap = DPPeekKeycap(key);
        [caps addObject:cap];
        capsWidth += NSWidth(cap.frame) + DPHintCapGap;
        capsHeight = NSHeight(cap.frame);
    }
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.textColor = NSColor.whiteColor;
    label.usesSingleLineMode = NO;
    label.cell.wraps = YES;
    label.cell.lineBreakMode = NSLineBreakByWordWrapping;

    BOOL stacked = caps.count && DPPeekFit(label, 10000).width + DPHintLabelGap + capsWidth > maxWidth;
    CGFloat capsBlock = caps.count && !stacked ? DPHintLabelGap + capsWidth : 0;
    NSSize fit = DPPeekFit(label, stacked ? MAX(MAX(40, capsWidth), maxWidth) : MAX(40, maxWidth - capsBlock));
    CGFloat content = stacked ? MAX(fit.width, capsWidth) : fit.width + capsBlock;
    CGFloat height = stacked ? 2 * DPHintPadY + fit.height + DPHintLabelGap + capsHeight
                             : MAX(DPHintHeight, MAX(fit.height, capsHeight) + 2 * DPHintPadY);

    NSView *pill = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, content + 2 * DPHintPadX, height)];
    pill.wantsLayer = YES;
    pill.layer.backgroundColor = [NSColor colorWithWhite:0.1 alpha:0.92].CGColor;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.cornerRadius = MIN(height / 2, 13);
    pill.alphaValue = 0;
    if (stacked) label.alignment = NSTextAlignmentCenter;
    label.frame = stacked ? NSMakeRect(DPHintPadX, height - DPHintPadY - fit.height, content, fit.height)
                          : NSMakeRect(DPHintPadX, (height - fit.height) / 2, fit.width, fit.height);
    [pill addSubview:label];
    CGFloat x = stacked ? DPHintPadX + (content - capsWidth) / 2 : NSMaxX(label.frame) + DPHintLabelGap;
    for (NSView *cap in caps) {
        cap.frame = NSMakeRect(x, stacked ? DPHintPadY : (height - NSHeight(cap.frame)) / 2, NSWidth(cap.frame), NSHeight(cap.frame));
        [pill addSubview:cap];
        x += NSWidth(cap.frame) + DPHintCapGap;
    }
    return pill;
}

void DPPeekLayoutHints(NSView *controls, CGFloat availableRight) {
    for (DPPeekButton *button in [controls.subviews copy]) {
        if (![button isKindOfClass:DPPeekButton.class]) continue;
        [button.pill removeFromSuperview];
        NSView *pill = DPPeekMakeHint(button.hintText, button.hintKeys, MAX(40, availableRight - DPHintRightGap - 2 * DPHintPadX));
        pill.frame = NSMakeRect(NSMaxX(button.frame) + DPHintRightGap, NSMidY(button.frame) - NSHeight(pill.frame) / 2, NSWidth(pill.frame), NSHeight(pill.frame));
        button.pill = pill;
        [controls addSubview:pill];
    }
}

// Fixed frames, not a stack view, which squeezed the circles out of shape.
NSView *DPPeekControls(id target, SEL action) {
    static const CGFloat side = 28, gap = 8;
    NSArray<NSDictionary *> *specs = @[
        @{@"symbol": @"xmark", @"a11y": @"Close Peek", @"hint": @"Close", @"keys": @[@"⌘", @"W"]},
        @{@"symbol": @"arrow.up.left.and.arrow.down.right", @"a11y": @"Open as Tab", @"hint": @"Expand", @"keys": @[@"⌘", @"O"]},
        @{@"symbol": @"rectangle.split.2x1", @"a11y": @"Create Split View", @"hint": @"Create Split View"},
    ];
    NSView *controls = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, side, specs.count * side + (specs.count - 1) * gap)];
    controls.clipsToBounds = NO;
    for (NSUInteger i = 0; i < specs.count; i++) {
        NSDictionary *spec = specs[i];
        NSImage *symbol = [[NSImage imageWithSystemSymbolName:spec[@"symbol"] accessibilityDescription:spec[@"a11y"]]
                           imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightSemibold]];
        NSImage *white = [NSImage imageWithSize:symbol.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
            [symbol drawInRect:rect];
            [NSColor.whiteColor set];
            NSRectFillUsingOperation(rect, NSCompositingOperationSourceAtop);
            return YES;
        }];

        DPPeekButton *button = [DPPeekButton buttonWithTitle:@"" target:target action:action];
        button.tag = i;
        button.bordered = NO;
        button.accessibilityLabel = spec[@"a11y"];
        button.hintText = spec[@"hint"];
        button.hintKeys = spec[@"keys"];
        button.wantsLayer = YES;
        button.frame = NSMakeRect(0, (specs.count - 1 - i) * (side + gap), side, side);

        button.circle = [CAShapeLayer layer];
        button.circle.fillColor = [NSColor colorWithWhite:0.08 alpha:0.9].CGColor;
        [button.layer addSublayer:button.circle];

        button.iconLayer = [CALayer layer];
        button.iconLayer.contents = white;
        button.iconLayer.contentsGravity = kCAGravityCenter;
        button.iconLayer.contentsScale = NSScreen.mainScreen.backingScaleFactor ?: 2;
        button.iconLayer.bounds = (CGRect){CGPointZero, white.size};
        [button.layer addSublayer:button.iconLayer];

        [controls addSubview:button];
    }
    return controls;
}
