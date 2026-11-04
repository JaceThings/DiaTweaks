#import "LittleDia.h"

// The bar's buttons, styled like Dia's own toolbar buttons: grey, darker with a soft fill under the pointer, faint when
// there's nothing to do.
@interface DPBarButton : NSButton
@property (nonatomic, copy) void (^handler)(void);
@property (nonatomic) BOOL hovered, pill;  // pill: a filled capsule with an icon and a word, like Dia's Chat button
@end

@implementation DPBarButton

- (instancetype)initWithSymbol:(NSString *)symbol size:(CGFloat)size label:(NSString *)label {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.bordered = NO;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 6;
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightSemibold];
    self.image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label] imageWithSymbolConfiguration:config];
    self.imagePosition = NSImageOnly;
    self.accessibilityLabel = label;
    self.toolTip = label;
    self.target = self;
    self.action = @selector(run:);
    [self updateTint];
    return self;
}

- (void)run:(id)sender { if (self.handler) self.handler(); }

- (NSSize)intrinsicContentSize {
    return self.pill ? NSMakeSize(ceil(super.intrinsicContentSize.width) + 20, 28) : NSMakeSize(28, 28);
}

- (BOOL)mouseDownCanMoveWindow { return NO; }

- (void)updateTint {
    self.contentTintColor = !self.enabled ? NSColor.tertiaryLabelColor : self.hovered || self.pill ? NSColor.labelColor : NSColor.secondaryLabelColor;
    self.needsDisplay = YES;
}

- (void)setEnabled:(BOOL)enabled {
    if (enabled == self.enabled) return;
    super.enabled = enabled;
    [self updateTint];
}

- (void)updateTrackingAreas {
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                       options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                         owner:self
                                                      userInfo:nil]];
    [super updateTrackingAreas];
}

- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; [self updateTint]; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; [self updateTint]; }

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)rect {
    CGFloat fill = self.pill ? (self.hovered ? 0.16 : 0.1) : (self.hovered && self.enabled ? 0.08 : 0);
    self.layer.backgroundColor = fill ? [NSColor.labelColor colorWithAlphaComponent:fill].CGColor : nil;
    [super drawRect:rect];
}

@end

NSButton *DPMakeBarButton(NSString *symbol, NSString *label, NSString *key, void (^action)(void)) {
    DPBarButton *button = [[DPBarButton alloc] initWithSymbol:symbol size:13 label:label];
    button.handler = action;
    if (key) {
        button.keyEquivalent = key;
        button.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    }
    return button;
}

// "Open in Dia": the page becomes a tab in the main window.
NSButton *DPMakeOpenInDiaButton(void (^action)(void)) {
    DPBarButton *button = [[DPBarButton alloc] initWithSymbol:@"arrow.up.forward" size:10 label:@"Open in Dia"];
    button.pill = YES;
    button.title = @"Open in Dia";
    button.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    button.imagePosition = NSImageTrailing;
    button.imageHugsTitle = YES;
    button.toolTip = @"Open this page in a tab (⌘O)";
    button.keyEquivalent = @"o";
    button.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    button.handler = action;
    [button updateTint];
    return button;
}
