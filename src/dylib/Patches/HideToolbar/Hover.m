#import "HideToolbar.h"

static const CGFloat DPToolbarHoverHeight = 8;
static char DPHoverKey;

static NSTimer *DPEase(CGFloat from, CGFloat to, void (^step)(CGFloat value, BOOL done)) {
    CFTimeInterval start = CACurrentMediaTime();
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *timer) {
        CGFloat t = MIN(1, (CACurrentMediaTime() - start) / 0.25);
        if (t == 1) [timer invalidate];
        step(from + (to - from) * t * t * (3 - 2 * t), t == 1);
    }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    return timer;
}

@implementation DPToolbarHover

+ (DPToolbarHover *)forPane:(NSView *)pane {
    return DPGet(pane, &DPHoverKey);
}

+ (DPToolbarHover *)attachToPane:(NSView *)pane {
    DPToolbarHover *hover = [self forPane:pane];
    if (hover) return hover;
    hover = [DPToolbarHover new];
    hover.pane = pane;
    DPSet(pane, &DPHoverKey, hover);
    return hover;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(windowResignedKey:) name:NSWindowDidResignKeyNotification object:nil];
    [center addObserver:self selector:@selector(reset) name:NSApplicationDidResignActiveNotification object:nil];
    return self;
}

- (void)dealloc {
    [_animation invalidate];
    [_hideTimer invalidate];
    [_inPlaceAnimation invalidate];
    if (_tracking) [_pane removeTrackingArea:_tracking];
    if (_edge) [_pane removeTrackingArea:_edge];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)stopReveal {
    [self.animation invalidate];
    [self.hideTimer invalidate];
    self.animation = self.hideTimer = nil;
    _revealed = NO;
    self.progress = 0;
}

- (void)stopInPlace {
    [self.inPlaceAnimation invalidate];
    self.inPlaceAnimation = nil;
    _inPlace = NO;
    self.inPlaceProgress = 0;
}

- (void)detach {
    [self stopReveal];
    [self stopInPlace];
    if (self.tracking) [self.pane removeTrackingArea:self.tracking];
    if (self.edge) [self.pane removeTrackingArea:self.edge];
    self.tracking = self.edge = nil;
    if (self.pane) DPSet(self.pane, &DPHoverKey, nil);
}

- (void)reset {
    if (!self.revealed && self.progress == 0 && !self.animation && !self.hideTimer) return;
    [self stopReveal];
    if (self.pane) DPApplyToolbar(self.pane);
}

- (void)windowResignedKey:(NSNotification *)notification {
    if (notification.object == self.pane.window) [self reset];
}

- (BOOL)watchesPointer {
    NSWindow *window = self.pane.window;
    return self.tracking && window.isKeyWindow && NSApp.isActive && !self.pane.hiddenOrHasHiddenAncestor;
}

// A quick move to the top of the page overshoots the strip, into the tabs at the top or past the
// window into the menu bar. Above the page, over its width and up to the top of the screen, counts too.
- (BOOL)pointerAbovePage {
    if (![self watchesPointer]) return NO;
    NSWindow *window = self.pane.window;
    NSPoint point = NSEvent.mouseLocation;
    NSRect page = [window convertRectToScreen:[self.pane convertRect:self.pane.bounds toView:nil]];
    NSRect screen = (window.screen ?: NSScreen.mainScreen).frame;
    return point.y >= NSMaxY(page) && point.y <= NSMaxY(screen) && point.x >= NSMinX(page) && point.x < NSMaxX(page);
}

- (BOOL)containsPointer {
    if (![self watchesPointer]) return NO;
    NSPoint point = [self.pane convertPoint:[self.pane.window convertPointFromScreen:NSEvent.mouseLocation] fromView:nil];
    return NSMouseInRect(point, self.tracking.rect, self.pane.isFlipped) || [self pointerAbovePage];
}

- (BOOL)toolbarHasFocus {
    NSResponder *responder = self.pane.window.firstResponder;
    if ([responder isKindOfClass:NSTextView.class] && ((NSTextView *)responder).isFieldEditor)
        responder = (NSResponder *)((NSTextView *)responder).delegate;
    return [responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:self.bar];
}

- (void)setRevealed:(BOOL)revealed {
    if (_revealed == revealed) return;
    _revealed = revealed;
    [self.animation invalidate];
    __weak DPToolbarHover *weakSelf = self;
    self.animation = DPEase(self.progress, revealed, ^(CGFloat value, BOOL done) {
        DPToolbarHover *me = weakSelf;
        if (!me.pane) return;
        me.progress = value;
        DPApplyToolbarOpacity(me);
        if (!done) return;
        me.animation = nil;
        DPApplyToolbar(me.pane);
    });
    DPApplyToolbar(self.pane);
}

- (void)setInPlace:(BOOL)inPlace {
    if (_inPlace == inPlace) return;
    _inPlace = inPlace;
    [self.inPlaceAnimation invalidate];
    __weak DPToolbarHover *weakSelf = self;
    self.inPlaceAnimation = DPEase(self.inPlaceProgress, inPlace, ^(CGFloat value, BOOL done) {
        DPToolbarHover *me = weakSelf;
        if (!me.pane) return;
        me.inPlaceProgress = value;
        if (done) me.inPlaceAnimation = nil;
        DPApplyToolbar(me.pane);
    });
}

- (void)mouseEntered:(NSEvent *)event {
    if (!DPHideToolbar.on || !DPRevealToolbarOnHover.on || ![self containsPointer]) return;
    [self.hideTimer invalidate];
    self.hideTimer = nil;
    self.revealed = YES;
}

- (void)mouseExited:(NSEvent *)event {
    // Leaving the page over its top, maybe past the strip between two moves, reveals the toolbar.
    BOOL above = [self pointerAbovePage];
    if (above && !self.revealed && DPHideToolbar.on && DPRevealToolbarOnHover.on) self.revealed = YES;
    // Growing the tracking area on reveal sends a stray exit.
    if (!self.revealed || ([self containsPointer] && !above) || self.hideTimer) return;
    __weak DPToolbarHover *weakSelf = self;
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
        DPToolbarHover *me = weakSelf;
        if (!me) return [timer invalidate];
        if ([me pointerAbovePage]) return;  // No events come from above the page: keep looking.
        if (![me containsPointer] && ([me toolbarHasFocus] || NSEvent.pressedMouseButtons)) return;
        [timer invalidate];
        me.hideTimer = nil;
        if (![me containsPointer]) me.revealed = NO;
    }];
}

- (void)updateForBar:(NSView *)bar bookmarks:(NSView *)bookmarks {
    self.bar = bar;
    self.bookmarks = bookmarks;
    if (DPHideToolbar.on || DPHideToolbar.progress > 0) self.inPlace = DPKeptInPlace(self.pane);
    else [self stopInPlace];
    NSRect rect = NSZeroRect;
    if (DPHideToolbar.on && DPRevealToolbarOnHover.on && !self.inPlace && !bar.hiddenOrHasHiddenAncestor) {
        rect = DPLaidOutFrame(bar);
        if (bookmarks) rect = NSUnionRect(rect, DPLaidOutFrame(bookmarks));
        rect = NSIntersectionRect(rect, self.pane.bounds);
        CGFloat height = MIN(DPToolbarHoverHeight, NSHeight(rect));
        if (self.revealed) {
            if (!self.pane.isFlipped) rect.origin.y -= DPToolbarHoverHeight;
            rect.size.height += DPToolbarHoverHeight;
            rect = NSIntersectionRect(rect, self.pane.bounds);
        } else {
            if (!self.pane.isFlipped) rect.origin.y = NSMaxY(rect) - height;
            rect.size.height = height;
        }
    } else {
        [self stopReveal];
    }
    NSRect edge = NSIsEmptyRect(rect) ? NSZeroRect : self.pane.bounds;
    if (!(self.edge && NSEqualRects(self.edge.rect, edge))) {
        if (self.edge) [self.pane removeTrackingArea:self.edge];
        self.edge = NSIsEmptyRect(edge) ? nil : [[NSTrackingArea alloc] initWithRect:edge options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                                               owner:self userInfo:nil];
        if (self.edge) [self.pane addTrackingArea:self.edge];
    }
    if (self.tracking && NSEqualRects(self.tracking.rect, rect)) return;
    if (self.tracking) [self.pane removeTrackingArea:self.tracking];
    self.tracking = nil;
    if (NSIsEmptyRect(rect)) return;
    self.tracking = [[NSTrackingArea alloc] initWithRect:rect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                   owner:self userInfo:nil];
    [self.pane addTrackingArea:self.tracking];
}
@end
