#import "CompactSidebar.h"

static NSHashTable<NSView *> *DPRoots, *DPHosts;
static char DPDiaFrameKey, DPHiddenKey, DPShownKey;
static BOOL DPPlacing;  // Set while the strip places a host, which isn't Dia asking for a frame.

// While Auto-Hide Tabs is on, Dia parks the sidebar off the window's left edge, hidden, until the pointer reaches that
// edge. It parks the sidebar itself until it first shows it, and from then the floating container it shows it in. The
// page card has the window's width meanwhile, which Dia lays out itself.
NSRect DPDiaHostFrame(NSView *host) {
    NSValue *dia = DPGet(host, &DPDiaFrameKey);
    return dia ? dia.rectValue : host.frame;
}

NSView *DPSidebarRootIn(NSWindow *window) {
    for (NSView *root in DPRoots) if (window && root.window == window) return root;
    return nil;
}

// Right around it, or around the view Dia wraps it in for its rounded corners.
static NSView *DPFloatAround(NSView *root) {
    if (!DPIsKind(root, DPDiaSidebarRoot)) return nil;
    NSView *around = DPIsKind(root.superview, DPDiaFloatingSidebar) ? root.superview : root.superview.superview;
    return DPIsKind(around, DPDiaFloatingSidebar) ? around : nil;
}

NSView *DPHostIn(NSWindow *window) {
    NSView *root = DPSidebarRootIn(window);
    return DPFloatAround(root) ?: root;
}

// The view Dia moves and hides: the container while the sidebar is in one, else the sidebar.
static BOOL DPIsHost(NSView *view) { return DPIsKind(view, DPDiaFloatingSidebar) || !DPFloatAround(view); }

// Dia showing the sidebar itself, from the window's edge, where the strip is: it's the strip, open.
static BOOL DPDiaReveals(NSView *host, NSRect dia) {
    return DPCompactSidebar.on && DPIsKind(host, DPDiaFloatingSidebar) && NSMaxX(dia) > 0 && ![DPGet(host, &DPHiddenKey) boolValue]
        && !DPStripHiddenIn(host.window);
}

BOOL DPDiaRevealing(NSView *host) { return host && DPDiaReveals(host, DPDiaHostFrame(host)); }

// Parked: moved off the window's left edge, or for the floating container also just hidden where it last showed. Or
// shown by Dia from the strip.
static BOOL DPParked(NSView *host, NSRect dia) {
    return NSMaxX(dia) <= 0 || (DPIsKind(host, DPDiaFloatingSidebar) && [DPGet(host, &DPHiddenKey) boolValue]) || DPDiaReveals(host, dia);
}

BOOL DPDiaParked(NSView *host) { return host && DPIsHost(host) && DPParked(host, DPDiaHostFrame(host)); }
BOOL DPStripOn(NSView *host) { return DPCompactSidebar.on && DPDiaParked(host) && !DPStripHiddenIn(host.window); }
BOOL DPStripShown(NSWindow *window) { return DPStripOn(DPHostIn(window)); }

// From where the strip settles, not where an animation has it now.
CGFloat DPStripRight(NSWindow *window) {
    NSView *host = DPHostIn(window);
    return [host.superview convertPoint:NSMakePoint(DPStripWidth * DPStripVisible(window), 0) toView:nil].x;
}

// Where Dia parks it, it shows as the strip at the window's left edge instead, or open at Dia's width, or on its way out
// of the window or in while ⌘S slides it.
static NSRect DPHostTarget(NSView *host) {
    NSRect dia = DPDiaHostFrame(host);
    if (DPDiaParked(host) && DPStripSliding(host.window)) {
        CGFloat x = -DPStripSlideDistance(host.window) * (1 - DPStripVisible(host.window));
        return NSMakeRect(x, NSMinY(dia), MIN(NSWidth(dia), DPStripWidth), NSHeight(dia));
    }
    // Dia sliding the sidebar in from the window's edge stops at the edge, as the strip opens it, not 3pt in.
    if (DPDiaRevealing(host)) return NSMakeRect(MIN(NSMinX(dia), 0), NSMinY(dia), NSWidth(dia), NSHeight(dia));
    if (!DPStripOn(host)) return dia;
    BOOL open = DPStripExpanded(host);
    CGFloat strip = MIN(NSWidth(dia), DPStripWidth + DPRevealRoom(host.window) * DPLightsReveal(host.window));
    return NSMakeRect(0, NSMinY(dia), open ? NSWidth(dia) : strip, NSHeight(dia));
}

void DPPlaceHost(NSView *host) {
    NSRect target = DPHostTarget(host);
    // Shown as the strip, or hidden as Dia keeps what it parks, as when ⌘S hides the strip or the patch is off.
    BOOL strip = DPStripOn(host), sliding = DPDiaParked(host) && DPStripSliding(host.window);
    BOOL hidden = strip || sliding ? NO : [(DPGet(host, &DPHiddenKey) ?: @(DPDiaParked(host))) boolValue];
    NSView *root = DPSidebarRootIn(host.window);
    if (DPFloatAround(root) != host) root = nil;
    BOOL rootHidden = !strip && !sliding && [DPGet(root, &DPHiddenKey) boolValue];
    DPPlacing = YES;
    if (!NSEqualRects(host.frame, target)) host.frame = target;
    if (host.hidden != hidden && DPIsHost(host)) host.hidden = hidden;
    if (root && root.hidden != rootHidden) root.hidden = rootHidden;
    DPPlacing = NO;
    if (DPCompactSidebar.on) DPAttachStrip(host);
    DPLayoutStrip(host);
    // The strip showing or going, or Dia docking the sidebar after it, moves the page, toolbar and window buttons.
    NSNumber *state = @(strip * 2 + DPDiaParked(host));
    if ([DPGet(host, &DPShownKey) isEqual:state]) return;
    DPSet(host, &DPShownKey, state);
    DPRefreshWindow(host.window);
}

// The strip, and the sidebar inside it once Dia has put the sidebar in its floating container, which Dia also hides.
static BOOL DPKeepsShowing(NSView *view) {
    NSView *host = DPHostIn(view.window);
    return DPStripOn(host) && (view == host || DPFloatAround(view) == host);
}

// Dia passes -0 for some edges; the frame AppKit keeps has +0.
static NSRect DPPlusZero(NSRect r) { return NSMakeRect(r.origin.x + 0.0, r.origin.y + 0.0, r.size.width + 0.0, r.size.height + 0.0); }

static void DPDiaAsked(NSView *host, NSRect frame) {
    [DPHosts addObject:host];
    if (DPIsKind(host, DPDiaSidebarRoot)) [DPRoots addObject:host];
    DPSet(host, &DPDiaFrameKey, @(DPPlusZero(frame)));
}

// Dia moves these with setFrame:, setFrameOrigin: and setFrameSize:. Each records what Dia asked for, then the strip
// places the view once from that, so Dia and the strip never take turns.
#define DP_HOST_HOOKS(Name)                                                                  \
    static void Name##_setFrame(NSView *self, SEL _cmd, NSRect frame) {                     \
        if (DPPlacing) return DPCallOriginal(Name##_setFrame, self, frame);                 \
        DPDiaAsked(self, frame);                                                             \
        DPPlaceHost(self);                                                                   \
    }                                                                                        \
    static void Name##_setFrameOrigin(NSView *self, SEL _cmd, NSPoint origin) {             \
        if (DPPlacing) return DPCallOriginal(Name##_setFrameOrigin, self, origin);          \
        DPDiaAsked(self, (NSRect){origin, DPDiaHostFrame(self).size});                      \
        DPPlaceHost(self);                                                                   \
    }                                                                                        \
    static void Name##_setFrameSize(NSView *self, SEL _cmd, NSSize size) {                  \
        if (DPPlacing) return DPCallOriginal(Name##_setFrameSize, self, size);              \
        DPDiaAsked(self, (NSRect){DPDiaHostFrame(self).origin, size});                      \
        DPPlaceHost(self);                                                                   \
    }                                                                                        \
    static void Name##_setHidden(NSView *self, SEL _cmd, BOOL hidden) {                     \
        if (DPPlacing) return DPCallOriginal(Name##_setHidden, self, hidden);               \
        BOOL was = DPStripOn(self);                                                          \
        DPSet(self, &DPHiddenKey, @(hidden));                                               \
        DPCallOriginal(Name##_setHidden, self, hidden && !DPKeepsShowing(self));            \
        if (DPStripOn(self) != was) DPPlaceHost(self); /* Hiding the container parks it. */ \
    }

DP_HOST_HOOKS(DPFloat)
DP_HOST_HOOKS(DPRoot)

// The page, the toolbar's buttons and the window buttons make room for the strip, or take it back.
void DPRefreshWindow(NSWindow *window) {
    DPRelayoutCompactPanes(window);
    for (NSView *pane in DPFindViews(DPDiaContentPane)) if (pane.window == window) DPApplyChrome(pane);
    for (NSView *bar in DPFindViews(DPDiaToolbar)) if (bar.window == window) bar.needsLayout = YES;
    DPClearLightsIn(window);
    DPSubview(DPSidebarRootIn(window), DPDiaSidebarHeader).needsLayout = YES;  // Its window buttons go back, or over the toolbar.
}

void DPRelayoutCompactSidebar(void) {
    for (NSView *host in DPHosts) {
        if (!DPIsHost(host)) continue;
        DPPlaceHost(host);
        host.needsLayout = YES;
    }
}

void DPInstallCompactFrames(void) {
    DPRoots = [NSHashTable weakObjectsHashTable];
    DPHosts = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaFloatingSidebar, @selector(setFrame:), (IMP)DPFloat_setFrame);
    DPHook(DPDiaFloatingSidebar, @selector(setFrameOrigin:), (IMP)DPFloat_setFrameOrigin);
    DPHook(DPDiaFloatingSidebar, @selector(setFrameSize:), (IMP)DPFloat_setFrameSize);
    DPHook(DPDiaFloatingSidebar, @selector(setHidden:), (IMP)DPFloat_setHidden);
    DPHook(DPDiaSidebarRoot, @selector(setFrame:), (IMP)DPRoot_setFrame);
    DPHook(DPDiaSidebarRoot, @selector(setFrameOrigin:), (IMP)DPRoot_setFrameOrigin);
    DPHook(DPDiaSidebarRoot, @selector(setFrameSize:), (IMP)DPRoot_setFrameSize);
    DPHook(DPDiaSidebarRoot, @selector(setHidden:), (IMP)DPRoot_setHidden);
}
