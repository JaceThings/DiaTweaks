#import "HideToolbar.h"

static const CGFloat DPNavSize = 30, DPNavGap = 5, DPEdgeInset = 2;
static const NSTimeInterval DPFadeIn = 0.15, DPPollInterval = 0.2;
static char DPHolderKey;

static NSButton *DPNavButton(NSString *symbol, id target, SEL action) {
    NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] target:target action:action];
    button.bezelStyle = NSBezelStyleAccessoryBarAction;
    button.showsBorderOnlyWhileMouseInside = YES;
    button.contentTintColor = NSColor.secondaryLabelColor;
    button.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium];
    return button;
}

static BOOL DPLoading(NSView *reload) {
    NSView *icon = DPFindView(reload, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaReloadIcon); });
    BOOL *loading = DPIvar(icon, "isLoading");
    return loading && *loading;
}

@implementation DPNavigationHolder {
    NSArray<NSButton *> *_buttons;
    NSButton *_menu;
    NSTimer *_poll;
    BOOL _stop;
}

+ (DPNavigationHolder *)inHeader:(NSView *)header create:(BOOL)create {
    DPNavigationHolder *holder = DPGet(header, &DPHolderKey);
    if (holder || !create || !header) return holder;
    holder = [DPNavigationHolder new];
    DPSet(header, &DPHolderKey, holder);
    [header addSubview:holder];
    return holder;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    NSMutableArray<NSButton *> *buttons = [NSMutableArray new];
    for (NSString *symbol in @[ @"chevron.left", @"chevron.right", @"arrow.clockwise" ]) {
        NSButton *button = DPNavButton(symbol, self, @selector(press:));
        button.tag = buttons.count;
        [buttons addObject:button];
        [self addSubview:button];
    }
    _buttons = buttons;
    _menu = DPNavButton(@"ellipsis", self, @selector(showMenu:));
    [self addSubview:_menu];
    self.hidden = YES;
    self.alphaValue = 0;
    return self;
}

- (void)dealloc { [_poll invalidate]; }

- (NSArray<NSView *> *)diaButtons { return (self.dia ? self.dia() : nil) ?: @[]; }

- (void)press:(NSButton *)sender {
    NSArray<NSView *> *dia = self.diaButtons;
    if ((NSUInteger)sender.tag < dia.count) [dia[sender.tag] accessibilityPerformPress];
    [self refresh];
}

- (void)showMenu:(NSButton *)sender {
    NSMenu *menu = [NSMenu new];
    menu.autoenablesItems = NO;
    for (NSButton *button in _buttons) {
        __weak DPNavigationHolder *me = self;
        NSMenuItem *item = DPMenuItem(button.accessibilityLabel ?: @"", ^{ [me press:button]; });
        item.enabled = button.enabled;
        [menu addItem:item];
    }
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight(sender.bounds) + 4) inView:sender];
}

// Copies what Dia's buttons show: which can be pressed, their names, and stop while a page loads.
- (void)refresh {
    NSArray<NSView *> *dia = self.diaButtons;
    [_buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger i, BOOL *stop) {
        NSView *real = i < dia.count ? dia[i] : nil;
        button.enabled = real && (![real respondsToSelector:@selector(isEnabled)] || [(NSControl *)real isEnabled]);
        if (![button.toolTip isEqual:real.accessibilityLabel]) button.toolTip = button.accessibilityLabel = real.accessibilityLabel;
    }];
    BOOL loading = DPLoading(dia.lastObject);
    if (loading != _stop) _buttons[2].image = [NSImage imageWithSystemSymbolName:loading ? @"xmark" : @"arrow.clockwise" accessibilityDescription:nil];
    _stop = loading;
}

// The rest of the row goes to what Dia shows there: window buttons, the profile, downloads and recent tabs.
- (NSRect)room {
    NSView *header = self.superview, *stack = DPSubview(header, "NSStackView");
    NSView *profile = DPFindView(stack, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaProfileButton); });
    if (!stack || !profile || profile.hiddenOrHasHiddenAncestor) return NSZeroRect;
    CGFloat left = NSMaxX([profile convertRect:profile.bounds toView:header]) + DPNavGap, right = NSMaxX(stack.frame) - DPEdgeInset;
    for (NSView *dia in [stack.subviews arrayByAddingObjectsFromArray:profile.superview.subviews]) {
        if (dia == profile || dia == profile.superview || dia.hidden || NSIsEmptyRect(dia.frame)) continue;
        CGFloat x = NSMinX([dia.superview convertRect:dia.frame toView:header]);
        if (x >= left - DPNavGap) right = MIN(right, x - DPNavGap);
    }
    return NSMakeRect(left, NSMidY(stack.frame) - DPNavSize / 2, MAX(0, right - left), DPNavSize);
}

- (void)show:(BOOL)wanted {
    _wanted = wanted;
    NSRect room = wanted ? self.room : NSZeroRect;
    CGFloat full = _buttons.count * (DPNavSize + DPNavGap) - DPNavGap;
    BOOL fits = NSWidth(room) >= full, shown = fits || NSWidth(room) >= DPNavSize;
    if (shown) {
        CGFloat width = fits ? full : DPNavSize;
        NSRect frame = NSMakeRect(NSMaxX(room) - width, NSMinY(room), width, DPNavSize);
        if (!NSEqualRects(self.frame, frame)) self.frame = frame;
        [_buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger i, BOOL *stop) {
            button.hidden = !fits;
            button.frame = NSMakeRect((DPNavSize + DPNavGap) * i, 0, DPNavSize, DPNavSize);
        }];
        _menu.hidden = fits;
        _menu.frame = self.bounds;
        [self refresh];
    }
    if (shown == !self.hidden) return;
    [_poll invalidate];
    _poll = nil;
    // Out at once so the toolbar has them back; in with a quick fade.
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = shown ? DPFadeIn : 0;
        self.animator.alphaValue = shown;
    }];
    self.hidden = !shown;
    if (!shown) return;
    __weak DPNavigationHolder *me = self;
    _poll = [NSTimer scheduledTimerWithTimeInterval:DPPollInterval repeats:YES block:^(NSTimer *timer) { [me refresh]; }];
}
@end
