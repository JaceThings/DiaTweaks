#import "CompactSidebar.h"

// Dia's downloads button follows the window buttons in their row, so in the strip it shows over the toolbar with them.
// There it looks like the toolbar's buttons: Dia's own highlight is the sidebar's, larger and rounder, and its hover
// doesn't track reliably that far outside the header, so the toolbar draws the hover behind it instead.
static char DPHoverKey, DPHidHighlightKey;

NSView *DPDownloadsIn(NSView *root) {
    NSView *header = root ? DPSubview(root, DPDiaSidebarHeader) : nil;
    return header ? DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaDownloadsButton); }) : nil;
}

static BOOL DPDownloadsUp(NSView *downloads) { return downloads && !downloads.hiddenOrHasHiddenAncestor && NSWidth(downloads.frame) > 0; }

static BOOL DPFlat(NSWindow *window) { return DPStripPresent(window) && !DPStripExpanded(DPHostIn(window)); }

CGFloat DPHeaderButtonsRight(NSWindow *window) {
    CGFloat right = DPLightsRight(window);
    NSView *downloads = DPDownloadsIn(DPSidebarRootIn(window));
    if (right > 0 && DPDownloadsUp(downloads)) right = MAX(right, NSMaxX([downloads convertRect:downloads.bounds toView:nil]));
    return right;
}

CGFloat DPDownloadsMid(NSWindow *window) {
    NSView *downloads = DPDownloadsIn(DPSidebarRootIn(window));
    if (!DPFlat(window) || DPLightsRight(window) <= 0 || !DPDownloadsUp(downloads)) return NAN;
    return NSMidX([downloads convertRect:downloads.bounds toView:nil]);
}

static BOOL DPIsDiaHighlight(NSView *view) {
    NSString *name = NSStringFromClass(view.class);
    return [name hasSuffix:@"TabBackgroundView"] || [name hasSuffix:@"TabHighlightView"];
}

// Over the toolbar, it fades with the toolbar, as the window buttons do. Without the window buttons, which Hide Window
// Controls takes out of the row, it would land on the toolbar's own buttons, so it shows once the sidebar opens.
void DPMatchDownloads(NSWindow *window) {
    NSView *downloads = DPDownloadsIn(DPSidebarRootIn(window));
    if (!downloads) return;
    BOOL flat = DPFlat(window);
    CGFloat alpha = !flat ? 1 : DPLightsRight(window) > 0 ? DPToolbarAlpha(window) : 0;
    if (downloads.alphaValue != alpha) downloads.alphaValue = alpha;
    // Dia's highlight goes while the toolbar's shows, and comes back only where this faded it. Faded, not hidden: hiding
    // it lays the button out again without it, which moves the icon.
    DPFindView(downloads, ^BOOL(NSView *v) {
        if (!DPIsDiaHighlight(v)) return NO;
        if (flat && v.alphaValue != 0) {
            v.alphaValue = 0;
            DPSet(v, &DPHidHighlightKey, @YES);
        } else if (!flat && [DPGet(v, &DPHidHighlightKey) boolValue]) {
            v.alphaValue = 1;
            DPSet(v, &DPHidHighlightKey, nil);
        }
        return NO;
    });
}

// The toolbar's buttons' hover and press, behind the downloads icon. It takes no clicks: they go to Dia's button.
@interface DPDownloadsHover : NSView
@property (nonatomic, weak) NSView *look;  // The toolbar's sidebar button, whose colors and corners it takes.
@property (nonatomic) BOOL hovered, pressed;
@end

@implementation DPDownloadsHover

- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    return self;
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)restyle {
    NSView *look = self.look;
    void **hover = look ? DPIvar(look, "hoveredBackgroundColor") : NULL, **press = look ? DPIvar(look, "pressedBackgroundColor") : NULL;
    NSColor *hovered = hover ? (__bridge NSColor *)*hover : nil, *pressed = press ? (__bridge NSColor *)*press : nil;
    NSColor *fill = self.pressed && self.hovered ? pressed : self.hovered ? hovered : nil;
    __block CGColorRef color = NULL;
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{ color = [fill isKindOfClass:NSColor.class] ? fill.CGColor : NULL; }];
    DPNow(^{
        self.layer.cornerRadius = look.layer.cornerRadius;
        self.layer.backgroundColor = color;
    });
}

- (void)setHovered:(BOOL)hovered { _hovered = hovered; [self restyle]; }
- (void)setPressed:(BOOL)pressed { _pressed = pressed; [self restyle]; }
- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self restyle]; }

@end

static NSHashTable<DPDownloadsHover *> *DPHovers;

// Clicks go to Dia's button, so the press shows from the window's events.
static void DPWatchPresses(void) {
    static id monitor;
    if (monitor) return;
    monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp handler:^NSEvent *(NSEvent *event) {
        for (DPDownloadsHover *hover in DPHovers.allObjects) {
            if (hover.window != event.window) continue;
            BOOL inside = !hover.hidden && NSPointInRect([hover convertPoint:event.locationInWindow fromView:nil], hover.bounds);
            BOOL pressed = event.type == NSEventTypeLeftMouseDown && inside;
            if (hover.pressed != pressed) hover.pressed = pressed;
        }
        return event;
    }];
}

void DPPlaceDownloadsHover(NSView *bar) {
    NSView *field = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); }), *items = field.superview;
    NSView *look = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaHoverableControl) && [v.accessibilityLabel isEqualToString:@"Toggle sidebar"]; });
    DPDownloadsHover *hover = DPGet(bar, &DPHoverKey);
    CGFloat mid = DPDownloadsMid(bar.window);
    BOOL show = items && look.superview == items && !look.hidden && !isnan(mid);
    if (!show) {
        hover.hidden = YES;
        return;
    }
    if (!hover) {
        DPSet(bar, &DPHoverKey, hover = [DPDownloadsHover new]);
        if (!DPHovers) DPHovers = [NSHashTable weakObjectsHashTable];
        [DPHovers addObject:hover];
        DPWatchPresses();
    }
    if (hover.superview != items) [items addSubview:hover positioned:NSWindowBelow relativeTo:nil];
    hover.look = look;
    hover.hidden = NO;
    CGFloat x = [items convertPoint:NSMakePoint(mid, 0) fromView:nil].x;
    NSRect frame = NSMakeRect(x - NSWidth(look.frame) / 2, NSMinY(look.frame), NSWidth(look.frame), NSHeight(look.frame));
    if (!NSEqualRects(hover.frame, frame)) DPNow(^{ hover.frame = frame; });
    [hover restyle];  // Dia retints its buttons for themes and appearance in layout.
}

BOOL DPIsDownloadsHover(NSView *view) { return [view isKindOfClass:DPDownloadsHover.class]; }
