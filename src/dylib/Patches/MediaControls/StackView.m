#import "Views.h"

NSNotificationName const DPMediaStackHeightDidChange = @"DPMediaStackHeightDidChange";

// The stack lays out from its bottom edge up. At rest the second card sits behind the front one, a little narrower,
// with only its top edge showing: that's the peek. Opening slides it up and out to full size above the front card.
@implementation DPMediaStackView {
    NSMutableArray<DPMediaCard *> *_cards;
    BOOL _open;
    NSUInteger _shown;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _cards = [NSMutableArray new];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (CGFloat)restHeight { return _shown ? DPRestHeight + (_shown > 1 ? DPPeekHeight : 0) : 0; }

- (CGFloat)height {
    if (!_shown || !_open) return self.restHeight;
    return _shown * DPExpandedHeight + (_shown - 1) * DPFanGap;
}

- (void)reload {
    CGFloat before = self.height;
    NSArray<DPMediaItem *> *items = self.stack.visible;
    _shown = items.count;
    while (_cards.count < items.count) {
        DPMediaCard *card = [DPMediaCard new];
        __weak DPMediaStackView *weak = self;
        card.dismiss = ^(DPMediaItem *item) {
            [weak.stack dismiss:item.tab];
            [weak reload];
        };
        [_cards addObject:card];
    }
    // Back to front, so the newest card is on top.
    for (NSInteger i = (NSInteger)_cards.count - 1; i >= 0; i--) {
        DPMediaCard *card = _cards[i];
        if ((NSUInteger)i >= items.count) { [card removeFromSuperview]; continue; }
        card.item = items[i];
        card.expanded = _open;
        [self addSubview:card positioned:NSWindowAbove relativeTo:nil];
    }
    if (!_shown) _open = NO;
    self.needsLayout = YES;
    if (self.height != before) [NSNotificationCenter.defaultCenter postNotificationName:DPMediaStackHeightDidChange object:self];
}

- (void)layout {
    [super layout];
    CGFloat w = NSWidth(self.bounds), bottom = NSHeight(self.bounds);
    for (NSUInteger i = 0; i < _shown; i++) {
        DPMediaCard *card = _cards[i];
        if (_open) {
            card.frame = NSMakeRect(0, bottom - DPExpandedHeight - i * (DPExpandedHeight + DPFanGap), w, DPExpandedHeight);
        } else {
            CGFloat inset = i ? DPPeekInset : 0;
            card.frame = NSMakeRect(inset, bottom - DPRestHeight - (i ? DPPeekHeight : 0), w - 2 * inset, DPRestHeight);
        }
        card.peeking = !_open && i > 0;
    }
}

#pragma mark Hover

- (void)updateTrackingAreas {
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                       options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect
                                                         owner:self
                                                      userInfo:nil]];
    [super updateTrackingAreas];
}

// The stack's frame, the cards and everything in them move together, on one curve.
- (void)setOpen:(BOOL)open {
    if (open == _open || (open && !_shown)) return;
    DPAnimate(^{
        self->_open = open;
        for (DPMediaCard *card in self->_cards) card.expanded = open;
        [NSNotificationCenter.defaultCenter postNotificationName:DPMediaStackHeightDidChange object:self];
        self.needsLayout = YES;
        [self layoutSubtreeIfNeeded];
    });
}

- (void)mouseEntered:(NSEvent *)event {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(close) object:nil];
    [self setOpen:YES];
}
// A short wait, so moving between the cards, or out and straight back, doesn't flicker.
- (void)mouseExited:(NSEvent *)event { [self performSelector:@selector(close) withObject:nil afterDelay:0.08]; }
- (void)close { [self setOpen:NO]; }

// Only the cards take the pointer; the gap between them lets clicks through to the tabs.
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    return hit == self ? nil : hit;
}

@end
