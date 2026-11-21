#import "Controls.h"
#import <objc/message.h>

@interface DPDevButton : NSButton
@property (nonatomic, copy) void (^handler)(DPDevButton *button);
@property (nonatomic, copy) void (^hover)(DPDevButton *button);
@property (nonatomic, copy) NSString *label, *menuTitle;
@property (nonatomic) BOOL hovered;
@end

static NSString *DPMenuKeys(NSString *title) {
    NSMenu *view = [NSApp.mainMenu itemWithTitle:@"View"].submenu;
    NSMenuItem *item = [[view itemWithTitle:@"Developer"].submenu itemWithTitle:title];
    if (!item.keyEquivalent.length) return nil;
    NSEventModifierFlags flags = item.keyEquivalentModifierMask;
    NSString *key = item.keyEquivalent;
    if (![key isEqualToString:key.lowercaseString]) flags |= NSEventModifierFlagShift;
    return [NSString stringWithFormat:@"%@%@%@%@%@", flags & NSEventModifierFlagControl ? @"⌃" : @"", flags & NSEventModifierFlagOption ? @"⌥" : @"",
                                      flags & NSEventModifierFlagShift ? @"⇧" : @"", flags & NSEventModifierFlagCommand ? @"⌘" : @"", key.uppercaseString];
}

@implementation DPDevButton
+ (instancetype)buttonWithImage:(NSImage *)image label:(NSString *)label handler:(void (^)(DPDevButton *))handler {
    DPDevButton *button = [DPDevButton new];
    button.image = image;
    button.bordered = NO;
    button.imagePosition = NSImageOnly;
    button.contentTintColor = NSColor.secondaryLabelColor;
    button.label = button.accessibilityLabel = label;
    button.handler = handler;
    button.target = button;
    button.action = @selector(press:);
    button.wantsLayer = YES;
    button.layer.cornerRadius = 5;
    [button.widthAnchor constraintEqualToConstant:22].active = YES;
    [button.heightAnchor constraintEqualToConstant:22].active = YES;
    [button addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:button userInfo:nil]];
    return button;
}
+ (instancetype)buttonWithSymbols:(NSString *)symbols label:(NSString *)label handler:(void (^)(DPDevButton *))handler {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightRegular];
    NSImage *image;
    for (NSString *name in [symbols componentsSeparatedByString:@" "])
        if ((image = [[NSImage imageWithSystemSymbolName:name accessibilityDescription:label] imageWithSymbolConfiguration:config])) break;
    return [self buttonWithImage:image label:label handler:handler];
}
- (NSEdgeInsets)alignmentRectInsets { return NSEdgeInsetsZero; }
- (void)press:(id)sender {
    DPHideTip();
    if (self.handler) self.handler(self);
}
- (void)mouseEntered:(NSEvent *)event {
    self.hovered = YES;
    [self updateLayer];
    if (!self.hover) return DPShowTip(self, self.label, self.menuTitle ? DPMenuKeys(self.menuTitle) : nil);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.hovered && self.window) self.hover(self);
    });
}
- (void)mouseExited:(NSEvent *)event {
    self.hovered = NO;
    [self updateLayer];
    DPHideTip();
}
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    [super updateLayer];
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.layer.backgroundColor = self.hovered ? [NSColor.labelColor colorWithAlphaComponent:0.08].CGColor : nil;
    }];
}
@end

static NSImage *DPSymbol(NSString *name, CGFloat size) {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightRegular];
    return [[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil] imageWithSymbolConfiguration:config];
}

// A tulip in the same frame apple.terminal uses, so it matches the symbols beside it.
static NSImage *DPPortraitIcon(void) {
    NSImage *frame = DPSymbol(@"rectangle", 13), *tulip = DPSymbol(@"camera.macro", 7);
    NSImage *icon = [NSImage imageWithSize:frame.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [frame drawInRect:rect];
        NSSize size = tulip.size;
        CGFloat nudge = 0.5;  // camera.macro draws its tulip about 0.4pt left of its own middle.
        [tulip drawInRect:NSMakeRect(NSMidX(rect) - size.width / 2 + nudge, NSMidY(rect) - size.height / 2, size.width, size.height)];
        return YES;
    }];
    icon.template = YES;
    return icon;
}

static id DPPageOfButton(NSView *button) {
    NSView *pane = DPPaneAbove(button);
    return pane ? DPPageIn(pane) : nil;
}

// Close devtools when they already show this panel, else switch to it.
static void DPTogglePanel(NSView *button, NSString *panel, SEL open) {
    id tools = [DPPageOfButton(button) performSelector:@selector(devTools)];
    if (!tools) return;
    void (^show)(void) = ^{ ((void (*)(id, SEL))objc_msgSend)(tools, open); };
    BOOL (*current)(id, SEL, void (^)(id), NSError **) = (void *)objc_msgSend;
    BOOL asked = [tools performSelector:@selector(toolboxWebContents)] && current(tools, @selector(currentPanel:error:), ^(id shown) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([shown isEqual:panel]) [tools performSelector:@selector(close)];
            else show();
        });
    }, NULL);
    if (!asked) show();
}

static NSView *DPDivider(void) {
    NSBox *line = [NSBox new];
    line.boxType = NSBoxSeparator;
    [line.heightAnchor constraintEqualToConstant:16].active = YES;
    return line;
}

static DPDevButton *DPPanelButton(NSString *symbols, NSString *label, NSString *menuTitle, NSString *panel, SEL open) {
    DPDevButton *button = [DPDevButton buttonWithSymbols:symbols label:label handler:^(DPDevButton *b) { DPTogglePanel(b, panel, open); }];
    button.menuTitle = menuTitle;
    return button;
}

NSView *DPMakeDevButtons(void) {
    void (^open)(DPDevButton *) = ^(DPDevButton *b) {
        id page = DPPageOfButton(b);
        if (page) DPShowPortraitPopover(b, page);
    };
    DPDevButton *portrait = [DPDevButton buttonWithImage:DPPortraitIcon() label:@"Capture in Portrait Mode" handler:open];
    portrait.hover = open;
    NSStackView *group = [NSStackView stackViewWithViews:@[
        portrait, DPDivider(),
        DPPanelButton(@"apple.terminal terminal", @"Toggle Console", @"JavaScript Console", @"console", @selector(openConsoleView)),
        DPPanelButton(@"network globe", @"Toggle Network Activity", nil, @"network", @selector(openNetworkView)),
        DPPanelButton(@"scope", @"Inspect Elements", @"Inspect Elements", @"elements", @selector(openInspectView)),
        DPDivider(),
    ]];
    group.spacing = 4;
    for (NSView *view in group.arrangedSubviews)
        if ([view isKindOfClass:NSBox.class]) {
            [group setCustomSpacing:6 afterView:view];
            NSUInteger index = [group.arrangedSubviews indexOfObject:view];
            if (index > 0) [group setCustomSpacing:6 afterView:group.arrangedSubviews[index - 1]];
        }
    return group;
}
