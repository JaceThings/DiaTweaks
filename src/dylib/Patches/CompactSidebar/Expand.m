#import "CompactSidebar.h"

static const NSTimeInterval DPOpenDelay = 0.12, DPCloseDelay = 0.25, DPOpenDuration = 0.2;
static const CGFloat DPCardRadius = 13;  // Dia's floating sidebar's corners.
static char DPStripKey, DPBorderKey, DPClipsKey;

// The view Dia puts the sidebar in inside its floating container.
static NSView *DPFloatInner(NSView *host) {
    NSView *root = DPSidebarRootIn(host.window);
    return root.superview != host && root.superview.superview == host ? root.superview : nil;
}

// The strip shows the chrome's color down the window's left, under the window buttons, without Dia's floating card
// around it. Open, the sidebar floats over the page in a card, as when Dia shows it from the window's edge.
@interface DPStrip : NSObject
@property (nonatomic, weak) NSView *host;
@property (nonatomic, strong) NSView *column, *fill;
@property (nonatomic) BOOL expanded;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation DPStrip

- (void)track {
    NSView *host = self.host;
    for (NSTrackingArea *area in host.trackingAreas) if (area.owner == self) return;
    [host addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

// On the tabs, not the header over the toolbar.
- (BOOL)pointerOnList {
    NSView *host = self.host, *root = DPSidebarRootIn(host.window);
    NSView *header = root ? DPSubview(root, DPDiaSidebarHeader) : nil;
    NSPoint p = host.window.mouseLocationOutsideOfEventStream;
    if (!NSPointInRect([host convertPoint:p fromView:nil], host.bounds)) return NO;
    return !header || !NSPointInRect([header convertPoint:p fromView:nil], header.bounds);
}

// Dia shows the sidebar itself when the pointer reaches the window's edge, which the strip covers; both at once glitch,
// so while the strip shows, Dia waits as it does after the user closed the sidebar there.
- (void)holdDiaBack {
    NSViewController *controller = self.host.window.contentViewController;
    BOOL *suppress = DPIsKind(controller, DPDiaWindowController) ? DPIvar(controller, "suppressSidebarHoverUntilPointerLeavesRevealRegion") : NULL;
    if (suppress && DPStripOn(self.host)) *suppress = YES;
}

- (BOOL)wantsOpen { return [self pointerOnList] || (self.expanded && NSEvent.pressedMouseButtons); }

- (void)settle {
    [self holdDiaBack];
    BOOL want = [self wantsOpen];
    [self.timer invalidate];
    if (want == self.expanded || !DPStripOn(self.host)) return;
    __weak DPStrip *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:want ? DPOpenDelay : DPCloseDelay repeats:NO block:^(NSTimer *t) {
        DPStrip *strip = weakSelf;
        if (strip && [strip wantsOpen] == want) [strip setOpen:want];
    }];
}

- (void)setOpen:(BOOL)open {
    NSView *host = self.host;
    if (!host || open == self.expanded) return;
    self.expanded = open;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPOpenDuration;
        context.allowsImplicitAnimation = YES;
        DPPlaceHost(host);
        [host layoutSubtreeIfNeeded];
    }];
    DPLayoutStrip(host);
    DPSubview(DPSidebarRootIn(host.window), DPDiaSidebarHeader).needsLayout = YES;  // Its profile switcher shows while open.
}

- (void)mouseEntered:(NSEvent *)event { [self settle]; }
- (void)mouseMoved:(NSEvent *)event { [self settle]; }
- (void)mouseExited:(NSEvent *)event { [self settle]; }

@end

static DPStrip *DPStripOf(NSView *host) { return host ? DPGet(host, &DPStripKey) : nil; }

BOOL DPStripExpanded(NSView *host) { return DPStripOf(host).expanded || DPDiaRevealing(host); }

void DPAttachStrip(NSView *host) {
    DPStrip *strip = DPStripOf(host);
    if (!strip) {
        strip = [DPStrip new];
        strip.host = host;
        strip.column = [NSView new];
        strip.column.wantsLayer = YES;
        DPSet(host, &DPStripKey, strip);
    }
    [strip track];
}

void DPLayoutStrip(NSView *host) {
    DPStrip *strip = DPStripOf(host);
    if (!strip) return;
    NSView *root = DPSidebarRootIn(host.window), *card = DPSubview(host.superview, DPDiaContentContainer);
    BOOL shown = DPStripPresent(host.window) && root && card;
    if (!shown) strip.expanded = NO;
    BOOL open = DPStripExpanded(host), flat = shown && !open, floating = DPIsKind(host, DPDiaFloatingSidebar);
    [strip holdDiaBack];

    // Dia's floating card, once the sidebar is in one: its shadow, and the background behind the sidebar.
    NSView *shadow = DPSubview(host, DPDiaShadowView);
    NSView *background = DPFindView(host, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaPopoverBackground); });
    for (NSView *view in @[ shadow ?: NSNull.null, background ?: NSNull.null ]) {
        if ((id)view == NSNull.null) continue;
        CGFloat alpha = flat ? 0 : 1;
        if (view.alphaValue != alpha) view.alphaValue = alpha;
    }

    // And the card's outline and rounded clip, which the container and the view inside it apply themselves. Flat, the
    // window buttons reach past the strip.
    if (floating) {
        NSNumber *border = DPGet(host, &DPBorderKey);
        if (!border) DPSet(host, &DPBorderKey, border = @(host.layer.borderWidth));
        CGFloat width = flat ? 0 : border.doubleValue;
        if (host.layer.borderWidth != width) DPNow(^{ host.layer.borderWidth = width; });
        NSView *inner = DPFloatInner(host);
        for (NSView *view in inner ? @[ host, inner ] : @[ host ]) {
            NSNumber *clips = DPGet(view, &DPClipsKey);
            if (!clips) DPSet(view, &DPClipsKey, clips = @(view.layer.masksToBounds));
            BOOL masks = !flat && clips.boolValue;
            if (view.layer.masksToBounds != masks) view.layer.masksToBounds = masks;
        }
    }

    // The window's margin round the page, in the strip's color too, so the two are one surface.
    NSView *space = host.superview;
    if (!strip.fill) {
        strip.fill = [NSView new];
        strip.fill.wantsLayer = YES;
    }
    if (card && (strip.fill.superview != space || [space.subviews indexOfObject:strip.fill] + 1 != [space.subviews indexOfObject:card]))
        [space addSubview:strip.fill positioned:NSWindowBelow relativeTo:card];
    strip.fill.hidden = !shown;
    if (shown) {
        strip.fill.frame = space.bounds;
        strip.fill.layer.backgroundColor = DPChromeColor(space.window, space.effectiveAppearance);
    }

    if (!root) return;
    if (root.subviews.firstObject != strip.column) [root addSubview:strip.column positioned:NSWindowBelow relativeTo:nil];  // Dia adds the tabs after it.
    // Open, a sidebar Dia hasn't put in its floating card yet gets a card like it.
    strip.column.hidden = !shown || (open && floating);
    if (strip.column.hidden) return;
    CALayer *layer = strip.column.layer;
    layer.backgroundColor = DPChromeColor(root.window, root.effectiveAppearance);
    if (open) {
        strip.column.frame = root.bounds;
        layer.cornerRadius = DPCardRadius;
        layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
        layer.shadowOpacity = 0.3;
        layer.shadowRadius = 10;
        return;
    }
    // The window's whole height from its edge, so the window's own background doesn't show beside it, and its corners
    // round the strip's.
    NSView *frameView = root.window.contentView.superview;
    NSRect window = [root convertRect:frameView.bounds fromView:frameView];
    CGFloat right = [root convertPoint:NSMakePoint(DPStripRight(root.window), 0) fromView:nil].x;
    CGFloat width = DPStripWidth + DPRevealRoom(root.window) * DPLightsReveal(root.window);  // Wider as the window buttons show.
    strip.column.frame = NSMakeRect(0, NSMinY(window), MAX(right, width), NSHeight(window));
    layer.cornerRadius = 0;
    layer.shadowOpacity = 0;
}
