#import "Patches/Boosts/Boosts.h"

// A paintbrush among the address field's own buttons, styled like them: 22 points square, a 5-point radius and a faint
// fill under the pointer. Dia shows those while the field is hovered and hides them otherwise, so the paintbrush
// follows the bookmark button. It's pink while the site has a Boost on.
#define DPAnchorLabels (@[ @"Bookmark this page", @"Site menu" ])
static char DPButtonKey;

@interface DPBoostButton : NSButton
@property (nonatomic, copy) NSString *symbol;  // Set only when it changes: a new image lays the field out again.
@property (nonatomic) BOOL hovered;
@property (nonatomic, strong) CALayer *fill;
@end

@implementation DPBoostButton

- (instancetype)init {
    if (!(self = [super initWithFrame:NSMakeRect(0, 0, 22, 22)])) return nil;
    self.bordered = NO;
    self.wantsLayer = YES;
    self.fill = [CALayer layer];
    self.fill.cornerRadius = 5;
    [self.layer addSublayer:self.fill];
    self.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightRegular];
    self.imagePosition = NSImageOnly;
    self.accessibilityLabel = @"Boost This Site";
    self.target = self;
    self.action = @selector(open:);
    [self.widthAnchor constraintEqualToConstant:22].active = YES;
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    return self;
}

- (void)open:(id)sender {
    NSString *domain = DPFrontDomain();
    if (!domain) return NSBeep();  // Not a web page.
    DPShowBoostEditor(domain);
}

- (void)sync {
    BOOL active = [DPBoostFor(DPFrontDomain())[@"enabled"] boolValue];
    NSString *symbol = active ? @"paintbrush.pointed.fill" : @"paintbrush.pointed";
    if ([symbol isEqual:self.symbol]) return;
    self.symbol = symbol;
    self.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@"Boost This Site"];
    [self restyle];
}

- (void)restyle {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        BOOL active = [self.symbol hasSuffix:@".fill"];
        self.contentTintColor = active ? NSColor.systemPinkColor : NSColor.secondaryLabelColor;
        self.fill.backgroundColor = self.hovered ? [NSColor.labelColor colorWithAlphaComponent:0.06].CGColor : NSColor.clearColor.CGColor;
    }];
}

// The field's stack gives it its full height, where Dia's own buttons keep to 22 points, so the fill sits in the middle.
- (void)layout {
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.fill.frame = NSMakeRect(0, round((NSHeight(self.bounds) - 22) / 2), 22, 22);
    [CATransaction commit];
}

- (void)setHovered:(BOOL)hovered { _hovered = hovered; [self restyle]; }
- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self restyle]; }
@end

static NSView *DPAnchor(NSView *field) {
    for (NSString *label in DPAnchorLabels) {
        NSView *found = DPFindView(field, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaFieldButton) && DPHasLabel(view, label); });
        if ([found.superview isKindOfClass:NSStackView.class]) return found;
    }
    return nil;
}

static void DPPlaceButton(NSView *field) {
    NSView *anchor = DPAnchor(field);
    DPBoostButton *button = DPGet(field, &DPButtonKey);
    if (!DPBoosts.on || !anchor) return [button removeFromSuperview];
    if (!button) DPSet(field, &DPButtonKey, button = [DPBoostButton new]);
    NSStackView *stack = (NSStackView *)anchor.superview;
    if (button.superview != stack) [stack insertArrangedSubview:button atIndex:[stack.arrangedSubviews indexOfObject:anchor]];
    if (button.hidden != anchor.hidden) button.hidden = anchor.hidden;
    [button sync];
}

static void DPField_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPField_layout, self);
    DPPlaceButton(self);
}

static NSView *DPFieldOf(NSView *view) {
    while (view && !DPIsKind(view, DPDiaAddressField)) view = view.superview;
    return view;
}

// Dia shows and hides its buttons as the pointer comes and goes, without laying the field out again.
static void DPFieldButton_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPFieldButton_setHidden, self, hidden);
    NSView *field = DPFieldOf(self);
    DPBoostButton *button = field ? DPGet(field, &DPButtonKey) : nil;
    if (button.superview && DPAnchor(field) == self) button.hidden = hidden;
}

NSView *DPBoostButtonIn(NSWindow *window) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) {
        DPBoostButton *button = DPGet(field, &DPButtonKey);
        if (button.window == window && !button.isHiddenOrHasHiddenAncestor) return button;
    }
    return nil;
}

void DPSyncBoostButtons(void) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) DPPlaceButton(field);
}

NSString *DPVerifyBoostButtons(DPPatch *patch) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) {
        if (!DPAnchor(field)) continue;
        DPBoostButton *button = DPGet(field, &DPButtonKey);
        if (patch->on != (button.superview != nil)) return patch->on ? @"no Boost button in the address field" : @"Boost button still in the address field";
    }
    return nil;
}

void DPInstallBoostButton(void) {
    DPHook(DPDiaAddressField, @selector(layout), (IMP)DPField_layout);
    DPHook(DPDiaFieldButton, @selector(setHidden:), (IMP)DPFieldButton_setHidden);
    // Each window's paintbrush shows the front tab's Boost, so they catch up as another window comes to the front.
    for (NSNotificationName name in @[ DPBoostsDidChangeNotification, NSWindowDidBecomeMainNotification ])
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *_) { DPSyncBoostButtons(); }];
}
