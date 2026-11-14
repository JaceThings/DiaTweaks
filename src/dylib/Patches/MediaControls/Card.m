#import "Views.h"

// Not flipped: everything is placed from the bottom edge, which stays where it is while the card grows upward.
@implementation DPMediaCard {
    NSVisualEffectView *_blur;
    NSImageView *_favicon;
    DPFadeText *_title, *_host;
    DPMediaButton *_previous, *_playPause, *_next, *_mute, *_close;
}

- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 10;
    self.layer.borderWidth = 0.5;
    self.layer.masksToBounds = YES;
    _blur = [NSVisualEffectView new];
    _blur.material = NSVisualEffectMaterialPopover;
    _blur.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    [self addSubview:_blur];
    _favicon = [NSImageView new];
    _favicon.imageScaling = NSImageScaleProportionallyUpOrDown;
    _title = [[DPFadeText alloc] initWithFont:[NSFont systemFontOfSize:12.5] color:NSColor.labelColor];
    _host = [[DPFadeText alloc] initWithFont:[NSFont systemFontOfSize:11] color:NSColor.secondaryLabelColor];
    __weak DPMediaCard *weak = self;
    void (^run)(DPMediaAction) = ^(DPMediaAction action) { if (weak.item) DPMediaPerform(weak.item, action); };
    _previous = [[DPMediaButton alloc] initWithAction:^{ run(DPMediaPrevious); }];
    _playPause = [[DPMediaButton alloc] initWithAction:^{ run(DPMediaPlayPause); }];
    _next = [[DPMediaButton alloc] initWithAction:^{ run(DPMediaNext); }];
    _mute = [[DPMediaButton alloc] initWithAction:^{ run(DPMediaToggleMute); }];
    _close = [[DPMediaButton alloc] initWithAction:^{ if (weak.dismiss && weak.item) weak.dismiss(weak.item); }];
    [_previous setSymbol:@"backward.fill" label:@"Previous"];
    [_next setSymbol:@"forward.fill" label:@"Next"];
    _close.pointSize = 9;
    _close.weight = NSFontWeightBold;
    [_close setSymbol:@"xmark" label:@"Dismiss"];
    _close.contentTintColor = NSColor.secondaryLabelColor;
    _close.layer.cornerRadius = 5;
    for (NSView *view in @[ _favicon, _title, _host, _previous, _playPause, _next, _mute, _close ]) [self addSubview:view];
    _host.alphaValue = _close.alphaValue = _previous.alphaValue = 0;
    return self;
}

- (BOOL)mouseDownCanMoveWindow { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {}
- (void)mouseUp:(NSEvent *)event { if (self.item) DPMediaPerform(self.item, DPMediaSelect); }  // Buttons take their own clicks.

- (void)setItem:(DPMediaItem *)item {
    BOOL sameTab = item.tab && item.tab == _item.tab;  // Only a change in the same tab animates its symbols.
    _item = item;
    _favicon.image = item.favicon ?: [NSImage imageWithSystemSymbolName:@"globe" accessibilityDescription:nil];
    _title.string = item.title ?: @"";
    _host.string = item.host ?: @"";
    _previous.enabled = item.canPrevious;
    _next.enabled = item.canNext;
    _playPause.enabled = _mute.enabled = YES;
    [_playPause setSymbol:item.playing ? @"pause.fill" : @"play.fill" label:item.playing ? @"Pause" : @"Play" animated:sameTab];
    [_mute setSymbol:item.muted ? @"speaker.slash.fill" : @"speaker.wave.2.fill" label:item.muted ? @"Unmute" : @"Mute" animated:sameTab];
    self.accessibilityLabel = item.title;
    self.needsLayout = YES;
}

- (void)setExpanded:(BOOL)expanded {
    _expanded = expanded;
    self.needsLayout = YES;
}

- (void)setPeeking:(BOOL)peeking {
    _peeking = peeking;
    self.needsLayout = YES;
}

// The controls keep their place in the bottom row in both shapes; opening only fades previous in beside them. The
// title rides up with the top edge, and the site and the ✕ fade in under and beside it.
- (void)layout {
    [super layout];
    CGFloat w = NSWidth(self.bounds), h = NSHeight(self.bounds), b = DPButtonSize;
    BOOL open = self.expanded;
    _blur.frame = self.bounds;  // Set each time: autoresizing it drifted after a few resizes, leaving a gap at the top.
    NSArray<NSButton *> *buttons = @[ _previous, _playPause, _next, _mute ];
    [buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger i, BOOL *stop) {
        button.frame = NSMakeRect(w - 4 - (buttons.count - i) * (b + 1), (DPRestHeight - b) / 2, b, b);
    }];
    CGFloat rowY = (DPRestHeight - 16) / 2, titleY = open ? h - 8 - 16 : rowY, wide = w - 32 - DPCloseSize - 10;
    _favicon.frame = NSMakeRect(9, open ? h - 32 : rowY, 16, 16);
    _title.frame = NSMakeRect(32, titleY, open ? wide : MAX(0, NSMinX(_playPause.frame) - 36), 16);
    _host.frame = NSMakeRect(32, open ? titleY - 15 : rowY, wide, 14);
    _close.frame = NSMakeRect(w - DPCloseSize - 6, h - DPCloseSize - 6, DPCloseSize, DPCloseSize);
    // Fading the card itself would blank its blurred surface, so a peeking card fades only what's on it.
    _favicon.alphaValue = _title.alphaValue = _playPause.alphaValue = _next.alphaValue = _mute.alphaValue = self.peeking ? 0 : 1;
    _previous.alphaValue = _host.alphaValue = _close.alphaValue = open && !self.peeking ? 1 : 0;
    for (DPMediaButton *button in @[ _previous, _playPause, _next, _mute, _close ]) [button syncHover];
}

- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    return (hit == _close || hit == _previous) && !self.expanded ? self : hit;  // Both only show while open.
}

- (void)updateLayer { self.layer.borderColor = [NSColor.labelColor colorWithAlphaComponent:0.12].CGColor; }
- (BOOL)wantsUpdateLayer { return YES; }

@end
