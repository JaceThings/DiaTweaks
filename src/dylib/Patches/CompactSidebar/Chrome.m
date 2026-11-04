#import "CompactSidebar.h"

// Like Zen, the strip, the toolbar and the space around the page share one color a shade darker than the page, and the
// page sits in it as a card with rounded corners.
static const CGFloat DPPageRadius = 10;
static char DPChromeKey, DPRoundedKey;

// Dia's toolbar color, which follows the page; nil until Dia has made the toolbar.
static NSColor *DPToolbarColor(NSView *bar) {
    NSView *fill = DPSubview(bar, DPDiaColorView);
    void **slot = fill ? DPIvar(fill, "backgroundColor") : NULL;
    id color = slot ? (__bridge id)*slot : nil;
    return [color isKindOfClass:NSColor.class] ? color : nil;
}

CGColorRef DPChromeColor(NSWindow *window, NSAppearance *appearance) {
    NSView *bar = nil;
    for (NSView *each in DPFindViews(DPDiaToolbar)) if (each.window == window) { bar = each; break; }
    NSColor *toolbar = DPToolbarColor(bar);
    if (!toolbar) return NULL;
    __block CGColorRef chrome = NULL;
    [appearance performAsCurrentDrawingAppearance:^{
        BOOL dark = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
        NSColor *rgb = [toolbar colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        chrome = [rgb blendedColorWithFraction:dark ? 0.2 : 0.05 ofColor:NSColor.blackColor].CGColor;
    }];
    return chrome;
}

// The page under the toolbar: the pane's widest view that reaches its bottom.
static NSView *DPPageIn(NSView *pane, NSView *bar) {
    NSView *page = nil;
    for (NSView *sub in pane.subviews) {
        if (sub == bar || sub.hidden || DPIsKind(sub, DPDiaBookmarksBar)) continue;
        BOOL reachesBottom = fabs((pane.isFlipped ? NSMaxY(sub.frame) : NSHeight(pane.bounds) - NSMinY(sub.frame)) - NSHeight(pane.bounds)) < 0.5;
        if (reachesBottom && NSHeight(sub.frame) < NSHeight(pane.bounds) && (!page || NSWidth(sub.frame) > NSWidth(page.frame))) page = sub;
    }
    return page;
}

void DPApplyChrome(NSView *pane) {
    NSView *bar = DPSubview(pane, DPDiaToolbar), *page = DPPageIn(pane, bar);
    BOOL on = DPStripPresent(pane.window) && bar;
    NSView *chrome = DPGet(pane, &DPChromeKey);
    if (on && !chrome) {
        DPSet(pane, &DPChromeKey, chrome = [NSView new]);
        chrome.wantsLayer = YES;
    }
    // Behind the pane, not in it: hide toolbar reorders the pane's views, and the two would keep reordering each other.
    NSView *holder = pane.superview;
    if (on && holder && (chrome.superview != holder || [holder.subviews indexOfObject:chrome] > [holder.subviews indexOfObject:pane]))
        [holder addSubview:chrome positioned:NSWindowBelow relativeTo:pane];
    chrome.hidden = !on;
    // The toolbar's own background and the line under it give way to the chrome.
    for (NSView *sub in bar.subviews) {
        if (!DPIsKind(sub, DPDiaColorView)) continue;
        CGFloat alpha = on ? 0 : 1;
        if (sub.alphaValue != alpha) sub.alphaValue = alpha;
    }
    // The page's corners round only while the strip shows, and go back square only if this rounded them.
    if (page && (on || [DPGet(page, &DPRoundedKey) boolValue])) {
        DPSet(page, &DPRoundedKey, @(on));
        page.wantsLayer = YES;
        page.layer.cornerRadius = on ? DPPageRadius : 0;
        page.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
        page.layer.masksToBounds = on;
    }
    if (!on) return;
    if (!NSEqualRects(chrome.frame, pane.frame)) chrome.frame = pane.frame;
    chrome.layer.backgroundColor = DPChromeColor(pane.window, pane.effectiveAppearance);
}

static void DPPane_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPane_layout, self);
    DPApplyChrome(self);
}

void DPInstallCompactChrome(void) {
    DPHook(DPDiaContentPane, @selector(layout), (IMP)DPPane_layout);
}
