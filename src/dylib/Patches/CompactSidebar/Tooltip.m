#import "CompactSidebar.h"

// Over the toolbar, the downloads button gets a tooltip like the toolbar's own buttons: a card under it with its name and
// shortcut, shown after the pointer rests on it. Dia's tooltips aren't reachable from here, so this draws one like them.
static const NSTimeInterval DPTooltipDelay = 0.6;
// Measured from Dia's: a 13pt title, 14pt key caps in a card 21pt tall.
static const CGFloat DPTooltipGap = 6, DPTooltipPadX = 8, DPTooltipHeight = 21, DPKeySide = 14, DPKeyPad = 3, DPKeySpacing = 3, DPTitleGap = 7;
static NSPanel *DPTooltip;
static NSTimer *DPTooltipTimer;

static NSMenuItem *DPMenuItemTitled(NSMenu *menu, NSString *title) {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqualToString:title] && item.keyEquivalent.length) return item;
        NSMenuItem *found = item.submenu ? DPMenuItemTitled(item.submenu, title) : nil;
        if (found) return found;
    }
    return nil;
}

// Its shortcut from Dia's Window › Downloads, as the keys the other tooltips show.
static NSArray<NSString *> *DPDownloadsKeys(void) {
    NSMenuItem *item = DPMenuItemTitled(NSApp.mainMenu, @"Downloads");
    if (!item) return @[];
    NSMutableArray *keys = [NSMutableArray new];
    NSEventModifierFlags mods = item.keyEquivalentModifierMask;
    if (mods & NSEventModifierFlagControl) [keys addObject:@"⌃"];
    if (mods & NSEventModifierFlagOption) [keys addObject:@"⌥"];
    if (mods & NSEventModifierFlagShift || ![item.keyEquivalent isEqualToString:item.keyEquivalent.lowercaseString]) [keys addObject:@"⇧"];
    if (mods & NSEventModifierFlagCommand) [keys addObject:@"⌘"];
    [keys addObject:item.keyEquivalent.uppercaseString];
    return keys;
}

static NSTextField *DPLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = color;
    [label sizeToFit];
    return label;
}

static NSView *DPTooltipCard(NSAppearance *appearance) {
    BOOL dark = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
    NSView *card = [NSView new];
    card.wantsLayer = YES;
    card.layer.cornerRadius = 6;
    card.layer.borderWidth = 1;
    card.layer.backgroundColor = [NSColor colorWithWhite:dark ? 0.15 : 0.98 alpha:1].CGColor;
    card.layer.borderColor = [NSColor colorWithWhite:dark ? 1 : 0 alpha:0.1].CGColor;
    NSColor *text = dark ? NSColor.whiteColor : NSColor.blackColor;
    NSTextField *title = DPLabel(@"Downloads", [NSFont systemFontOfSize:13], text);
    CGFloat x = DPTooltipPadX;
    NSMutableArray<NSView *> *views = [NSMutableArray arrayWithObject:title];
    x += NSWidth(title.frame) + DPTitleGap;
    for (NSString *key in DPDownloadsKeys()) {
        NSTextField *label = DPLabel(key, [NSFont systemFontOfSize:10 weight:NSFontWeightMedium], text);
        NSView *cap = [NSView new];
        cap.wantsLayer = YES;
        cap.layer.cornerRadius = 3;
        cap.layer.backgroundColor = [NSColor colorWithWhite:dark ? 1 : 0 alpha:0.18].CGColor;
        cap.frame = NSMakeRect(x, 0, MAX(DPKeySide, NSWidth(label.frame) + 2 * DPKeyPad), DPKeySide);
        label.frame = NSMakeRect(round((NSWidth(cap.frame) - NSWidth(label.frame)) / 2), round((DPKeySide - NSHeight(label.frame)) / 2),
                                 NSWidth(label.frame), NSHeight(label.frame));
        [cap addSubview:label];
        [views addObject:cap];
        x += NSWidth(cap.frame) + DPKeySpacing;
    }
    card.frame = NSMakeRect(0, 0, ceil(x - (views.count > 1 ? DPKeySpacing : DPTitleGap) + DPTooltipPadX), DPTooltipHeight);
    for (NSView *view in views) {
        NSRect frame = view.frame;
        frame.origin.x = view == title ? DPTooltipPadX : frame.origin.x;
        frame.origin.y = round((NSHeight(card.frame) - NSHeight(frame)) / 2);
        view.frame = frame;
        [card addSubview:view];
    }
    return card;
}

void DPHideDownloadsTooltip(void) {
    [DPTooltipTimer invalidate];
    DPTooltipTimer = nil;
    [DPTooltip.parentWindow removeChildWindow:DPTooltip];
    [DPTooltip orderOut:nil];
}

static void DPShowTooltipUnder(NSView *view) {
    NSWindow *window = view.window;
    if (!window || view.hiddenOrHasHiddenAncestor) return;
    if (!DPTooltip) {
        DPTooltip = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                 backing:NSBackingStoreBuffered defer:YES];
        DPTooltip.opaque = NO;
        DPTooltip.backgroundColor = NSColor.clearColor;
        DPTooltip.hasShadow = YES;
        DPTooltip.ignoresMouseEvents = YES;
        DPTooltip.releasedWhenClosed = NO;
    }
    NSView *card = DPTooltipCard(view.effectiveAppearance);
    NSRect under = [window convertRectToScreen:[view convertRect:view.bounds toView:nil]];
    NSRect frame = NSMakeRect(round(NSMidX(under) - NSWidth(card.frame) / 2), NSMinY(under) - DPTooltipGap - NSHeight(card.frame),
                              NSWidth(card.frame), NSHeight(card.frame));
    DPTooltip.contentView = card;
    [DPTooltip setFrame:frame display:YES];
    if (DPTooltip.parentWindow != window) {
        [DPTooltip.parentWindow removeChildWindow:DPTooltip];
        [window addChildWindow:DPTooltip ordered:NSWindowAbove];
    }
    [DPTooltip orderFront:nil];
}

void DPShowDownloadsTooltip(NSView *view) {
    DPHideDownloadsTooltip();
    __weak NSView *weakView = view;
    DPTooltipTimer = [NSTimer scheduledTimerWithTimeInterval:DPTooltipDelay repeats:NO block:^(NSTimer *t) {
        DPTooltipTimer = nil;
        NSView *strong = weakView;
        if (strong) DPShowTooltipUnder(strong);
    }];
}
