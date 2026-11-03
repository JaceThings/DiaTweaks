#import "Patches/Peek/Peek.h"

static const CGFloat DPHintHeight = 26, DPHintPadX = 10, DPHintPadY = 5, DPHintLabelGap = 6, DPHintCapGap = 4, DPHintRightGap = 10;

// Arc's round controls take the first click, so one press on them works straight away. Each grows a little on hover and
// shows a hint pill to its right after the pointer settles, like a tooltip. Open in Split View has no shortcut yet, so
// its pill is a label with no keycap.
@interface DPPeekButton : NSButton
@property (nonatomic, weak) NSView *pill;
@property (nonatomic, copy) NSString *hintText;
@property (nonatomic, copy) NSArray<NSString *> *hintKeys;
@end

@implementation DPPeekButton
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer { self.layer.backgroundColor = [NSColor colorWithWhite:0.08 alpha:self.isHighlighted ? 0.7 : 0.9].CGColor; }

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
                                                       options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                         owner:self userInfo:nil]];
}

- (void)grow:(BOOL)hovered {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.12;
        context.allowsImplicitAnimation = YES;
        self.layer.transform = hovered ? CATransform3DMakeScale(1.12, 1.12, 1) : CATransform3DIdentity;
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
    // The button grows at once; the hint pill waits like a tooltip until the pointer has settled.
    [self performSelector:@selector(showHint) withObject:nil afterDelay:1.0];
}

- (void)mouseExited:(NSEvent *)event {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showHint) object:nil];
    [self grow:NO];
    self.pill.alphaValue = 0;
}
@end

// A keycap badge like Dia's shortcut hints: a light rounded square with the glyph.
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

static NSTextField *DPPeekHintLabel(NSString *text) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.textColor = NSColor.whiteColor;
    label.usesSingleLineMode = NO;
    label.cell.wraps = YES;
    label.cell.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

// A dark hint pill sized to its content, hidden until hover. Label and keycaps sit in a row when they fit the space to
// the right; when they don't, the keycaps stack centred under the label so the pill stays narrow and grows taller
// instead of spilling past the window edge. A label with no keycaps just wraps.
static NSView *DPPeekMakeHint(NSString *text, NSArray<NSString *> *keys, CGFloat maxContentWidth) {
    NSMutableArray<NSView *> *caps = [NSMutableArray array];
    CGFloat capsWidth = 0, capsHeight = 0;
    for (NSString *key in keys) {
        NSView *cap = DPPeekKeycap(key);
        [caps addObject:cap];
        capsWidth += NSWidth(cap.frame) + DPHintCapGap;
        capsHeight = NSHeight(cap.frame);
    }
    if (caps.count) capsWidth -= DPHintCapGap;

    NSTextField *label = DPPeekHintLabel(text);
    CGFloat lineWidth = ceil([label.cell cellSizeForBounds:NSMakeRect(0, 0, 10000, 10000)].width);
    BOOL stacked = caps.count && lineWidth + DPHintLabelGap + capsWidth > maxContentWidth;

    NSView *pill = [NSView new];
    pill.wantsLayer = YES;
    pill.layer.backgroundColor = [NSColor colorWithWhite:0.1 alpha:0.92].CGColor;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.alphaValue = 0;

    if (stacked) {
        CGFloat labelMax = MAX(MAX(40, capsWidth), maxContentWidth);
        NSSize labelSize = [label.cell cellSizeForBounds:NSMakeRect(0, 0, labelMax, 10000)];
        labelSize.width = ceil(labelSize.width);
        labelSize.height = ceil(labelSize.height);
        CGFloat content = MAX(labelSize.width, capsWidth);
        CGFloat width = DPHintPadX + content + DPHintPadX;
        CGFloat height = DPHintPadY + labelSize.height + DPHintLabelGap + capsHeight + DPHintPadY;
        pill.frame = NSMakeRect(0, 0, width, height);
        label.alignment = NSTextAlignmentCenter;
        label.frame = NSMakeRect(DPHintPadX, height - DPHintPadY - labelSize.height, content, labelSize.height);
        [pill addSubview:label];
        CGFloat x = DPHintPadX + (content - capsWidth) / 2;
        for (NSView *cap in caps) {
            cap.frame = NSMakeRect(x, DPHintPadY, NSWidth(cap.frame), NSHeight(cap.frame));
            [pill addSubview:cap];
            x += NSWidth(cap.frame) + DPHintCapGap;
        }
    } else {
        CGFloat capsBlock = caps.count ? DPHintLabelGap + capsWidth : 0;
        CGFloat labelMax = MAX(40, maxContentWidth - capsBlock);
        NSSize labelSize = [label.cell cellSizeForBounds:NSMakeRect(0, 0, labelMax, 10000)];
        labelSize.width = ceil(labelSize.width);
        labelSize.height = ceil(labelSize.height);
        CGFloat height = MAX(DPHintHeight, MAX(labelSize.height, capsHeight) + 2 * DPHintPadY);
        CGFloat width = DPHintPadX + labelSize.width + capsBlock + DPHintPadX;
        pill.frame = NSMakeRect(0, 0, width, height);
        label.frame = NSMakeRect(DPHintPadX, (height - labelSize.height) / 2, labelSize.width, labelSize.height);
        [pill addSubview:label];
        CGFloat x = NSMaxX(label.frame) + DPHintLabelGap;
        for (NSView *cap in caps) {
            cap.frame = NSMakeRect(x, (height - NSHeight(cap.frame)) / 2, NSWidth(cap.frame), NSHeight(cap.frame));
            [pill addSubview:cap];
            x += NSWidth(cap.frame) + DPHintCapGap;
        }
    }
    pill.layer.cornerRadius = MIN(NSHeight(pill.frame) / 2, 13);
    return pill;
}

// Lays each button's hint pill to its right, wrapping within `availableRight`, the space to the controls' right edge.
void DPPeekLayoutHints(NSView *controls, CGFloat availableRight) {
    for (NSView *view in [controls.subviews copy]) {
        if (![view isKindOfClass:DPPeekButton.class]) continue;
        DPPeekButton *button = (DPPeekButton *)view;
        if (!button.hintText) continue;
        [button.pill removeFromSuperview];
        CGFloat maxContentWidth = MAX(40, availableRight - DPHintRightGap - 2 * DPHintPadX);
        NSView *pill = DPPeekMakeHint(button.hintText, button.hintKeys, maxContentWidth);
        pill.frame = NSMakeRect(NSMaxX(button.frame) + DPHintRightGap, NSMidY(button.frame) - NSHeight(pill.frame) / 2, NSWidth(pill.frame), NSHeight(pill.frame));
        button.pill = pill;
        [controls addSubview:pill];
    }
}

// Top to bottom: close, open as tab, open in split view. Each button's tag is the exit it stands for. Fixed frames
// rather than a stack view, which squeezed the circles out of shape.
NSView *DPPeekControls(id target, SEL action) {
    static const CGFloat side = 28, gap = 8;
    NSArray<NSDictionary *> *specs = @[
        @{@"symbol": @"xmark", @"a11y": @"Close Peek", @"hint": @"Close", @"keys": @[@"⌘", @"W"]},
        @{@"symbol": @"arrow.up.left.and.arrow.down.right", @"a11y": @"Open as Tab", @"hint": @"Expand", @"keys": @[@"⌘", @"O"]},
        @{@"symbol": @"rectangle.split.2x1", @"a11y": @"Create Split View", @"hint": @"Create Split View"},  // Label only: no shortcut yet.
    ];
    NSView *controls = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, side, specs.count * side + (specs.count - 1) * gap)];
    controls.clipsToBounds = NO;  // The hint pills reach right of the buttons.
    for (NSUInteger i = 0; i < specs.count; i++) {
        NSDictionary *spec = specs[i];
        DPPeekButton *button = [DPPeekButton buttonWithImage:[NSImage imageWithSystemSymbolName:spec[@"symbol"] accessibilityDescription:spec[@"a11y"]]
                                                      target:target action:action];
        button.tag = i;
        button.bordered = NO;
        button.toolTip = nil;  // The hover pill is the hint.
        button.hintText = spec[@"hint"];
        button.hintKeys = spec[@"keys"];
        button.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightBold];
        button.contentTintColor = NSColor.whiteColor;
        button.imagePosition = NSImageOnly;
        button.wantsLayer = YES;
        button.layer.cornerRadius = side / 2;
        button.layer.cornerCurve = kCACornerCurveCircular;
        button.layer.anchorPoint = CGPointMake(0.5, 0.5);  // So hover scales it about its centre.
        button.frame = NSMakeRect(0, (specs.count - 1 - i) * (side + gap), side, side);
        [controls addSubview:button];
    }
    return controls;
}
