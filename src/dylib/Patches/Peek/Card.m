#import "Patches/Peek/Peek.h"

// The card sits over the window's page area only, so the sidebar stays sharp and usable, as in Arc. It lives in Dia's
// rounded page, like the command bar's shade, so it clips to the page's corners and slides with it when the sidebar
// shows or hides; from the window's root view it jumped to the end of the slide at once.
@implementation DPPeekCard

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

// Arc's card is nearly full height and inset at the sides, with the controls in the right margin.
// Expanding grows it toward the whole page area.
- (NSRect)cardFrame {
    NSRect card = NSInsetRect(self.bounds, NSWidth(self.bounds) * 0.09, MAX(10, NSHeight(self.bounds) * 0.012)), page = self.bounds;
    CGFloat g = self.grown;
    return NSMakeRect(NSMinX(card) + (NSMinX(page) - NSMinX(card)) * g, NSMinY(card) + (NSMinY(page) - NSMinY(card)) * g,
                      NSWidth(card) + (NSWidth(page) - NSWidth(card)) * g, NSHeight(card) + (NSHeight(page) - NSHeight(card)) * g);
}

- (void)layout {
    [super layout];
    self.blur.frame = self.bounds;
    self.card.frame = self.cardFrame;
    self.clip.frame = self.card.bounds;
    self.host.frame = self.clip.bounds;
    NSSize size = self.controls.frame.size;
    self.controls.frame = (NSRect){{NSMaxX(self.card.frame) + 12, NSMinY(self.card.frame)}, size};
    // The hints are rebuilt hidden; inside the sidebar's slide they'd otherwise fade in from showing.
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0;
        context.allowsImplicitAnimation = NO;
        DPPeekLayoutHints(self.controls, NSWidth(self.bounds) - NSMaxX(self.controls.frame) - 8);
    }];
}

// Follows the page area as the sidebar opens and closes. Dia resizes the page inside an animation group as the sidebar
// slides, so the card resizes along with it on the same timing rather than jumping to the end.
- (void)followPane {
    NSView *pane = self.pane, *root = self.superview;
    if (!pane.window || !root) return;
    NSRect frame = [root convertRect:pane.bounds fromView:pane];
    if (NSEqualRects(frame, self.frame)) return;
    NSAnimationContext *dia = NSAnimationContext.currentContext;
    if (!dia.timingFunction) return (void)(self.frame = frame);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = dia.duration;
        context.timingFunction = dia.timingFunction;
        context.allowsImplicitAnimation = YES;
        self.animator.frame = frame;
        [self layoutSubtreeIfNeeded];
    }];
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
    DPPeekHideTabBadge(self);
    return YES;
}

// Closing shrinks it back into the link. Opening it as a tab first grows it to fill the page area it'll take, so the
// page doesn't jump. Opening it in a split goes at once, since the split lays the page out somewhere else.
- (void)close:(NSInteger)exit {
    if (![self stopWatching]) return;
    if (exit == 0) [self animateOut:^{ [self finish:0]; }];
    else if (exit == 1) [self animateExpand:^{ [self finish:1]; }];
    else [self finish:exit];
}

- (void)handOver {
    if (![self stopWatching]) return;
    [self.page detachFromPaneHostView:self.host];
    [self removeFromSuperview];
}

@end

DPPeekCard *DPPeekCardIn(NSWindow *window) {
    return (DPPeekCard *)DPFindView(window.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:DPPeekCard.class] && !((DPPeekCard *)view).closing;
    });
}

// The rounded page holding `pane`, or the window's root view if Dia's layout changed.
static NSView *DPPeekHolder(NSWindow *window, NSView *pane) {
    for (NSView *view = pane; view && view != window.contentView; view = view.superview)
        if (view.layer.cornerRadius > 0 && view.layer.masksToBounds) return view;
    return window.contentView;
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
    NSView *holder = DPPeekHolder(window, pane);
    DPPeekCard *peek = [[DPPeekCard alloc] initWithFrame:pane ? [holder convertRect:pane.bounds fromView:pane] : holder.bounds];
    peek.autoresizingMask = pane ? NSViewNotSizable : NSViewWidthSizable | NSViewHeightSizable;
    peek.pane = pane;
    peek.page = page;
    peek.host = host;
    // A translucent scrim rather than an NSVisualEffectView: Dia's page is GPU-composited, so a within-window blur
    // can't sample it and falls back to an opaque dark fill. The page keeps rendering behind the card, so a light
    // scrim leaves the original page visible and recedes it, as in Arc.
    NSView *blur = DPLayerView();
    blur.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:DPPeekDarkness()].CGColor;
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
    [holder addSubview:peek positioned:NSWindowAbove relativeTo:nil];
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
    // It grows out of a small link-sized box right where you clicked, so the open reads as coming from the link.
    NSRect card = peek.cardFrame;
    NSSize size = NSMakeSize(MAX(120, NSWidth(card) * 0.10), MAX(44, NSHeight(card) * 0.055));
    NSRect seed = NSMakeRect(origin.x - size.width / 2, origin.y - size.height / 2, size.width, size.height);
    peek.link = [peek convertRect:[window convertRectFromScreen:seed] fromView:nil];
    [peek animateIn];
    return peek;
}
