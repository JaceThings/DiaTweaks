#import "../DiaPatches.h"

static NSHashTable<NSView *> *DPPanes;
static char DPRequestedFrameKey, DPAssignedFrameKey, DPFillsKey, DPToolbarHoverKey;
static const CGFloat DPToolbarHoverHeight = 8;

static NSRect DPLaidOutFrame(NSView *view) {
    NSValue *assigned = objc_getAssociatedObject(view, &DPAssignedFrameKey);
    if (assigned && NSEqualRects(assigned.rectValue, view.frame))
        return [objc_getAssociatedObject(view, &DPRequestedFrameKey) rectValue];
    return view.frame;
}

static void DPAssignFrame(NSView *view, NSRect laidOut, NSRect frame) {
    objc_setAssociatedObject(view, &DPRequestedFrameKey, [NSValue valueWithRect:laidOut], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &DPAssignedFrameKey, [NSValue valueWithRect:frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.frame = frame;
}

static Class DPToolbarClass(void) {
    static Class cls;
    return cls = cls ?: NSClassFromString(@"_TtC13NavigationBar17NavigationBarView");
}

static Class DPPaneClass(void) {
    static Class cls;
    return cls = cls ?: NSClassFromString(@"_TtC11ContentPane15ContentPaneView");
}

static Class DPBookmarksBarClass(void) {
    static Class cls;
    return cls = cls ?: NSClassFromString(@"_TtC11BookmarkBar15BookmarkBarView");
}

static void DPApplyToolbar(NSView *pane);

@interface DPToolbarHover : NSObject
@property (nonatomic, weak) NSView *pane, *bar, *bookmarks;
@property (nonatomic, strong) NSTrackingArea *tracking;
@property (nonatomic, strong) NSTimer *animation, *hideTimer;
@property (nonatomic) BOOL revealed;
@property (nonatomic) CGFloat progress;
@end

@implementation DPToolbarHover

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
    if (_tracking) [_pane removeTrackingArea:_tracking];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)reset {
    [self.animation invalidate];
    [self.hideTimer invalidate];
    self.animation = self.hideTimer = nil;
    _revealed = NO;
    self.progress = 0;
    if (self.pane) DPApplyToolbar(self.pane);
}

- (void)windowResignedKey:(NSNotification *)notification {
    if (notification.object == self.pane.window) [self reset];
}

- (BOOL)containsPointer {
    NSWindow *window = self.pane.window;
    if (!window.isKeyWindow || !NSApp.isActive || self.pane.hiddenOrHasHiddenAncestor) return NO;
    NSPoint point = [self.pane convertPoint:[window convertPointFromScreen:NSEvent.mouseLocation] fromView:nil];
    return self.tracking && NSMouseInRect(point, self.tracking.rect, self.pane.isFlipped);
}

- (BOOL)toolbarHasFocus {
    NSResponder *responder = self.pane.window.firstResponder;
    // The shared field editor lives outside the toolbar; its delegate is the edited control.
    if ([responder isKindOfClass:NSTextView.class] && ((NSTextView *)responder).isFieldEditor)
        responder = (NSResponder *)((NSTextView *)responder).delegate;
    return [responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:self.bar];
}

- (void)setRevealed:(BOOL)revealed {
    if (_revealed == revealed) return;
    _revealed = revealed;
    [self.animation invalidate];
    CGFloat from = self.progress, target = revealed;
    CFTimeInterval start = CACurrentMediaTime();
    __weak DPToolbarHover *weakSelf = self;
    self.animation = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *timer) {
        DPToolbarHover *me = weakSelf;
        if (!me.pane) return [timer invalidate];
        CGFloat t = MIN(1, (CACurrentMediaTime() - start) / 0.25);
        me.progress = from + (target - from) * t * t * (3 - 2 * t);
        DPApplyToolbar(me.pane);
        if (t == 1) {
            [timer invalidate];
            me.animation = nil;
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:self.animation forMode:NSRunLoopCommonModes];
    DPApplyToolbar(self.pane);
}

- (void)mouseEntered:(NSEvent *)event {
    if (!DPHideToolbar.on || !DPRevealToolbarOnHover.on || ![self containsPointer]) return;
    [self.hideTimer invalidate];
    self.hideTimer = nil;
    self.revealed = YES;
}

- (void)mouseExited:(NSEvent *)event {
    // Growing the tracking area on reveal sends an exit from the old, narrow strip.
    if (!self.revealed || [self containsPointer] || self.hideTimer) return;
    __weak DPToolbarHover *weakSelf = self;
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
        DPToolbarHover *me = weakSelf;
        if (!me) return [timer invalidate];
        if (![me containsPointer] && ([me toolbarHasFocus] || NSEvent.pressedMouseButtons)) return;
        [timer invalidate];
        me.hideTimer = nil;
        if (![me containsPointer]) me.revealed = NO;
    }];
}

- (void)updateForBar:(NSView *)bar bookmarks:(NSView *)bookmarks {
    self.bar = bar;
    self.bookmarks = bookmarks;
    NSRect rect = NSZeroRect;
    if (DPHideToolbar.on && DPRevealToolbarOnHover.on && !bar.hiddenOrHasHiddenAncestor) {
        rect = DPLaidOutFrame(bar);
        if (bookmarks) rect = NSUnionRect(rect, DPLaidOutFrame(bookmarks));
        rect = NSIntersectionRect(rect, self.pane.bounds);
        CGFloat height = MIN(DPToolbarHoverHeight, NSHeight(rect));
        if (self.revealed) {
            // A margin below the revealed bar keeps it from flickering at its edge.
            if (!self.pane.isFlipped) rect.origin.y -= DPToolbarHoverHeight;
            rect.size.height += DPToolbarHoverHeight;
            rect = NSIntersectionRect(rect, self.pane.bounds);
        } else {
            if (!self.pane.isFlipped) rect.origin.y = NSMaxY(rect) - height;
            rect.size.height = height;
        }
    } else {
        [self.animation invalidate];
        [self.hideTimer invalidate];
        self.animation = self.hideTimer = nil;
        _revealed = NO;
        self.progress = 0;
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

// The bar stays in Dia's layout: hiding it makes Dia reflow in ways it won't undo.
static NSView *DPToolbar_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    DPToolbarHover *hover = objc_getAssociatedObject(self.superview, &DPToolbarHoverKey);
    BOOL hidden = DPHideToolbar.on && hover.progress == 0 && (self == hover.bar || self == hover.bookmarks);
    return hidden ? nil : DPCallOriginal(NSView *(*)(id, SEL, NSPoint), self, _cmd, point);
}

static NSView *DPToolbarIn(NSView *pane) {
    for (NSView *sub in pane.subviews) if ([sub isKindOfClass:DPToolbarClass()]) return sub;
    return nil;
}

// Distances from the pane's top, whichever way it's flipped.
static CGFloat DPTop(NSView *pane, NSRect r) { return pane.isFlipped ? NSMinY(r) : NSHeight(pane.bounds) - NSMaxY(r); }
static CGFloat DPBottom(NSView *pane, NSRect r) { return pane.isFlipped ? NSMaxY(r) : NSHeight(pane.bounds) - NSMinY(r); }

// Dia lays the bookmarks bar out right under the toolbar, so it hides and shows with it.
static NSView *DPBookmarksUnder(NSView *pane, NSView *bar) {
    for (NSView *sub in pane.subviews)
        if ([sub isKindOfClass:DPBookmarksBarClass()] && !sub.hidden && fabs(DPTop(pane, DPLaidOutFrame(sub)) - DPBottom(pane, bar.frame)) < 0.5) return sub;
    return nil;
}

static void DPApplyToolbar(NSView *pane) {
    NSView *bar = DPToolbarIn(pane);
    if (!bar) return;

    NSView *bookmarks = DPBookmarksUnder(pane, bar);
    NSArray<NSView *> *bars = bookmarks ? @[bar, bookmarks] : @[bar];

    DPToolbarHover *hover = objc_getAssociatedObject(pane, &DPToolbarHoverKey);
    if (!hover) {
        hover = [DPToolbarHover new];
        hover.pane = pane;
        objc_setAssociatedObject(pane, &DPToolbarHoverKey, hover, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [hover updateForBar:bar bookmarks:bookmarks];

    CGFloat progress = DPHideToolbar.progress;
    for (NSView *view in bars) view.alphaValue = 1 - progress * (1 - hover.progress);
    NSIndexSet *slots = [pane.subviews indexesOfObjectsPassingTest:^BOOL(NSView *sub, NSUInteger i, BOOL *stop) { return [bars containsObject:sub]; }];
    BOOL onTop = slots.firstIndex == pane.subviews.count - bars.count, atBottom = slots.lastIndex == bars.count - 1;
    // Revealed on hover, the bars float over the page instead of pushing it down.
    if (hover.revealed || hover.progress > 0) {
        if (!onTop) for (NSView *view in bars) [pane addSubview:view positioned:NSWindowAbove relativeTo:nil];
    } else if (progress > 0 && !atBottom) {
        for (NSView *view in bars.reverseObjectEnumerator) [pane addSubview:view positioned:NSWindowBelow relativeTo:nil];
    } else if (progress == 0 && slots.firstIndex == 0) {
        for (NSView *view in bars) [pane addSubview:view positioned:NSWindowAbove relativeTo:nil];
    }

    CGFloat edge = DPBottom(pane, DPLaidOutFrame(bars.lastObject)), shift = (edge - DPTop(pane, bar.frame)) * progress;
    NSMutableArray<NSView *> *stack = [NSMutableArray new];
    for (NSView *sub in pane.subviews) if (![bars containsObject:sub]) [stack addObject:sub];
    [stack sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        return [@(DPTop(pane, DPLaidOutFrame(a))) compare:@(DPTop(pane, DPLaidOutFrame(b)))];
    }];
    for (NSView *view in stack) {
        NSRect laidOut = DPLaidOutFrame(view);
        if (fabs(DPTop(pane, laidOut) - edge) > 0.5) continue;
        BOOL reachesBottom = fabs(DPBottom(pane, laidOut) - NSHeight(pane.bounds)) < 0.5;
        if (!reachesBottom) edge = DPBottom(pane, laidOut);
        NSRect frame = laidOut;
        if (reachesBottom) frame.size.height += shift;
        if (pane.isFlipped) frame.origin.y -= shift;
        else if (!reachesBottom) frame.origin.y += shift;
        DPAssignFrame(view, laidOut, frame);
        // Dia sizes the web view once instead of autoresizing it.
        for (NSView *child in view.subviews) {
            if (!objc_getAssociatedObject(child, &DPFillsKey)) {
                if (!NSEqualRects(child.frame, (NSRect){NSZeroPoint, laidOut.size})) continue;
                objc_setAssociatedObject(child, &DPFillsKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            child.frame = view.bounds;
        }
    }
}

static void DPPane_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    [DPPanes addObject:self];
    DPApplyToolbar(self);
}

static void DPRelayoutPanes(void) {
    for (NSView *pane in DPPanes) {
        pane.needsLayout = YES;
        [pane layoutSubtreeIfNeeded];
    }
}

static void DPInstallHideToolbar(void) {
    DPPanes = [NSHashTable weakObjectsHashTable];
    DPHook(DPPaneClass(), @selector(layout), DPPane_layout);
    DPHook(DPToolbarClass(), @selector(hitTest:), DPToolbar_hitTest);
    DPHook(DPBookmarksBarClass(), @selector(hitTest:), DPToolbar_hitTest);
}

static NSString *DPVerifyHideToolbar(DPPatch *patch) {
    NSArray<NSView *> *panes = DPFindViews(DPPaneClass());
    if (!panes.count) return @"no toolbar found";
    for (NSView *pane in panes) {
        NSView *bar = DPToolbarIn(pane);
        if (!bar) return @"no toolbar found";
        DPToolbarHover *hover = objc_getAssociatedObject(pane, &DPToolbarHoverKey);
        if (hover.progress > 0) continue;  // Revealed by the pointer.
        NSView *bookmarks = DPBookmarksUnder(pane, bar);
        NSArray<NSView *> *bars = bookmarks ? @[bar, bookmarks] : @[bar];
        BOOL hidden = patch->on, found = NO;
        for (NSView *view in bars) {
            if (fabs(view.alphaValue - (hidden ? 0 : 1)) > 0.01) return hidden ? @"toolbar still shows" : @"toolbar is invisible";
            if (hidden && [view hitTest:NSMakePoint(NSMidX(view.frame), NSMidY(view.frame))]) return @"toolbar still takes clicks";
        }
        CGFloat edge = DPBottom(pane, DPLaidOutFrame(bars.lastObject));
        for (NSView *view in pane.subviews) {
            NSRect laidOut = DPLaidOutFrame(view);
            if ([bars containsObject:view] || view.hidden || fabs(DPTop(pane, laidOut) - edge) > 0.5) continue;
            found = YES;
            CGFloat shift = hidden ? edge - DPTop(pane, bar.frame) : 0;
            if (fabs(DPTop(pane, view.frame) - (DPTop(pane, laidOut) - shift)) > 0.5)
                return hidden ? @"page didn't move up into the toolbar's place" : @"page isn't below the toolbar";
        }
        if (!found) return @"no page found below the toolbar";
    }
    return nil;
}

static NSString *DPVerifyRevealToolbar(DPPatch *patch) {
    for (NSView *pane in DPFindViews(DPPaneClass())) {
        DPToolbarHover *hover = objc_getAssociatedObject(pane, &DPToolbarHoverKey);
        NSView *bar = DPToolbarIn(pane);
        BOOL watching = patch->on && DPHideToolbar.on && bar && !bar.hiddenOrHasHiddenAncestor;
        if ((hover.tracking != nil) != watching) return watching ? @"nothing watches the top of the page" : @"still watching the top of the page";
        if (watching && !hover.revealed && bar.alphaValue > 0.01) return @"toolbar shows while the pointer is away";
    }
    return nil;
}

static NSColor *DPGray(void) { return NSColor.systemGrayColor; }

DPPatch DPHideToolbar = {
    .key = @"hideToolbar",
    .title = @"Hide toolbar",
    .detail = @"Remove the bar with the address, navigation buttons and extensions. Experimental.",
    .symbol = @"menubar.rectangle",
    .tint = DPGray,
    .classes = DPClasses("_TtC11ContentPane15ContentPaneView", "_TtC13NavigationBar17NavigationBarView"),
    .install = DPInstallHideToolbar,
    .relayout = DPRelayoutPanes,
    .verify = DPVerifyHideToolbar,
};

static NSColor *DPTeal(void) { return NSColor.systemTealColor; }
static void DPApplyReveal(DPPatch *patch) { DPRelayoutPanes(); }

DPPatch DPRevealToolbarOnHover = {
    .key = @"revealToolbarOnHover",
    .title = @"Reveal toolbar on hover",
    .detail = @"Show the hidden toolbar while the pointer is at the top of the page.",
    .symbol = @"cursorarrow",
    .tint = DPTeal,
    .requires = &DPHideToolbar,
    .apply = DPApplyReveal,
    .verify = DPVerifyRevealToolbar,
};
