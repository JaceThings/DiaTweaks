#import "Patches/Peek/Peek.h"

// The card sits over the window's page area only, so the sidebar stays sharp and usable, as in Arc. It's a child of
// the window's own root view: replacing the root clears the controller Dia relies on.
@implementation DPPeekCard

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

// Arc's card is nearly full height and inset at the sides, with the controls in the right margin.
- (NSRect)cardFrame { return NSInsetRect(self.bounds, NSWidth(self.bounds) * 0.09, MAX(10, NSHeight(self.bounds) * 0.012)); }

- (void)layout {
    [super layout];
    self.blur.frame = self.bounds;
    self.card.frame = self.cardFrame;
    self.clip.frame = self.card.bounds;
    self.host.frame = self.clip.bounds;
    NSSize size = self.controls.frame.size;
    self.controls.frame = (NSRect){{NSMaxX(self.card.frame) + 12, NSMinY(self.card.frame)}, size};
}

// Follows the page area as the sidebar opens and closes.
- (void)followPane {
    NSView *pane = self.pane, *root = self.superview;
    if (!pane.window || !root) return;
    NSRect frame = [root convertRect:pane.bounds fromView:pane];
    if (!NSEqualRects(frame, self.frame)) self.frame = frame;
}

- (void)mouseDown:(NSEvent *)event { [self close:0]; }
- (void)rightMouseDown:(NSEvent *)event {}
- (void)scrollWheel:(NSEvent *)event {}
- (void)control:(NSButton *)sender { [self close:sender.tag]; }

- (BOOL)stopWatching {
    if (self.closing) return NO;
    self.closing = YES;
    if (self.monitor) [NSEvent removeMonitor:self.monitor];
    if (self.paneObserver) [NSNotificationCenter.defaultCenter removeObserver:self.paneObserver];
    self.monitor = self.paneObserver = nil;
    self.controls.alphaValue = 0;
    return YES;
}

// Opening it as a tab or in a split goes at once, since the page is about to show up there; closing shrinks it away.
- (void)close:(NSInteger)exit {
    if (![self stopWatching]) return;
    if (exit) [self finish:exit];
    else [self animateOut:^{ [self finish:0]; }];
}

- (void)handOver {
    if (![self stopWatching]) return;
    [self.page detachFromPaneHostView:self.host];
    [self removeFromSuperview];
}

@end

DPPeekCard *DPPeekCardIn(NSWindow *window) {
    for (NSView *view in window.contentView.subviews)
        if ([view isKindOfClass:DPPeekCard.class] && !((DPPeekCard *)view).closing) return (DPPeekCard *)view;
    return nil;
}

static NSView *DPLayerView(void) {
    NSView *view = [NSView new];
    view.wantsLayer = YES;
    return view;
}

// Escape or ⌘W closes it, as in Arc, and ⌘O opens it as a tab. Escape reaches a field being edited first, so it can
// cancel the edit there. Key codes: O 31, W 13, Escape 53.
static id DPWatchKeys(DPPeekCard *card) {
    __weak DPPeekCard *weak = card;
    return [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        DPPeekCard *peek = weak;
        if (!peek || event.window != peek.window) return event;
        NSEventModifierFlags mods = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~NSEventModifierFlagCapsLock;
        BOOL command = mods == NSEventModifierFlagCommand, editing = [peek.window.firstResponder isKindOfClass:NSText.class];
        if (command && event.keyCode == 31) [peek close:1];
        else if ((command && event.keyCode == 13) || (!mods && event.keyCode == 53 && !editing)) [peek close:0];
        else return event;
        return nil;
    }];
}

DPPeekCard *DPPeekShowCard(NSWindow *window, id<DPPeekPage> page, NSPoint origin) {
    NSView *host = [page createPaneHostView], *pane = nil;
    if (!window || !host || DPPeekCardIn(window)) return nil;
    for (NSView *candidate in DPFindViews(DPDiaContentPane))
        if (candidate.window == window && NSWidth(candidate.bounds) * NSHeight(candidate.bounds) > NSWidth(pane.bounds) * NSHeight(pane.bounds)) pane = candidate;
    DPPeekCard *peek = [[DPPeekCard alloc] initWithFrame:pane ? [window.contentView convertRect:pane.bounds fromView:pane] : window.contentView.bounds];
    peek.autoresizingMask = pane ? NSViewNotSizable : NSViewWidthSizable | NSViewHeightSizable;
    peek.pane = pane;
    peek.page = page;
    peek.host = host;
    NSVisualEffectView *blur = [NSVisualEffectView new];
    blur.material = NSVisualEffectMaterialFullScreenUI;
    blur.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    blur.state = NSVisualEffectStateActive;
    blur.wantsLayer = YES;
    peek.blur = blur;
    peek.card = DPLayerView();
    peek.card.layer.shadowOpacity = 0.35;
    peek.card.layer.shadowRadius = 24;
    peek.card.layer.shadowOffset = CGSizeMake(0, -6);
    peek.clip = DPLayerView();
    peek.clip.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
    peek.clip.layer.cornerRadius = 10;
    peek.clip.layer.cornerCurve = kCACornerCurveContinuous;
    peek.clip.layer.masksToBounds = YES;
    peek.controls = DPPeekControls(peek, @selector(control:));
    [peek.clip addSubview:host];
    [peek.card addSubview:peek.clip];
    for (NSView *view in @[peek.blur, peek.card, peek.controls]) [peek addSubview:view];
    [window.contentView addSubview:peek positioned:NSWindowAbove relativeTo:nil];
    [peek layoutSubtreeIfNeeded];
    [page attachToPaneHostView:host];
    [window makeFirstResponder:host];
    if (pane) {
        pane.postsFrameChangedNotifications = YES;
        __weak DPPeekCard *weak = peek;
        peek.paneObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSViewFrameDidChangeNotification object:pane queue:nil
                                                                        usingBlock:^(NSNotification *note) { [weak followPane]; }];
    }
    peek.monitor = DPWatchKeys(peek);
    // It grows out of a link-sized box where you clicked.
    NSRect card = peek.cardFrame;
    NSSize size = NSMakeSize(MAX(180, NSWidth(card) * 0.16), MAX(70, NSHeight(card) * 0.1));
    NSRect seed = NSMakeRect(origin.x - size.width / 2, origin.y - size.height / 2, size.width, size.height);
    peek.link = [peek convertRect:[window convertRectFromScreen:seed] fromView:nil];
    [peek animateIn];
    return peek;
}
