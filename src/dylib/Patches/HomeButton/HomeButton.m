#import "HomeButton.h"

static NSHashTable<NSView *> *DPBars;
static char DPHomeKey, DPFieldFrameKey;

static BOOL DPIsReload(NSView *view) { return strcmp(object_getClassName(view), DPDiaReloadButton) == 0; }

// Dia lays out the toolbar's buttons by frame, left to right. The house goes after reload, and the address field gives up
// as much of its left side as the house needs.
static void DPPlaceHome(NSView *bar) {
    NSView *reload = DPFindView(bar, ^BOOL(NSView *v) { return DPIsReload(v); });
    NSView *field = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); });
    DPHomeButtonView *home = DPGet(bar, &DPHomeKey);
    BOOL show = DPHomeButton.on && reload && !reload.hidden && reload.superview;
    if (show && !home) DPSet(bar, &DPHomeKey, home = [DPHomeButtonView new]);
    if (show && home.superview != reload.superview) [reload.superview addSubview:home positioned:NSWindowAbove relativeTo:reload];
    home.hidden = !show;
    if (show) home.frame = NSMakeRect(NSMaxX(reload.frame) + DPHomeGap, NSMinY(reload.frame), DPHomeSize, DPHomeSize);
    [home restyle];  // Dia retints its buttons for themes and appearance in layout.

    if (!field) return;
    NSRect laidOut = [DPDiaValue(field, &DPFieldFrameKey, @(field.frame)) rectValue], frame = laidOut;
    CGFloat overlap = show && field.superview == home.superview ? NSMaxX(home.frame) + DPHomeGap - NSMinX(laidOut) : 0;
    if (overlap > 0) {
        frame.origin.x += overlap;
        frame.size.width = MAX(0, NSWidth(frame) - overlap);
    }
    DPOverride(field, &DPFieldFrameKey, @(laidOut), @(frame));
    if (!NSEqualRects(field.frame, frame)) field.frame = frame;
}

static void DPBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPBar_layout, self);
    [DPBars addObject:self];
    DPPlaceHome(self);
}

static void DPInstallHomeButton(void) {
    DPBars = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPBar_layout);
}

static void DPApplyHomeButton(DPPatch *patch) { DPRelayoutViews(DPBars); }

static NSString *DPVerifyHomeButton(DPPatch *patch) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) {
        if (bar.hiddenOrHasHiddenAncestor || !bar.window.isVisible) continue;
        NSView *reload = DPFindView(bar, ^BOOL(NSView *v) { return DPIsReload(v); });
        NSView *home = DPFindView(bar, ^BOOL(NSView *v) { return [v isKindOfClass:DPHomeButtonView.class] && !v.hidden; });
        NSView *field = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); });
        if (!patch->on) {
            if (home) return @"home button still shows";
            continue;
        }
        if (!reload || reload.hidden) continue;
        if (!home) return @"no home button";
        if (fabs(NSMinX(home.frame) - NSMaxX(reload.frame) - DPHomeGap) > 0.5) return @"home button isn't after reload";
        if (field && NSMinX(field.frame) < NSMaxX(home.frame)) return @"address field covers the home button";
    }
    return nil;
}

DP_PATCH(DPHomeButton) {
    .key = @"homeButton",
    .order = 49,
    .title = @"Home Button",
    .detail = @"Add a house after the reload button that opens your home page in the current tab.",
    .symbol = @"house.fill",
    .tint = @"systemBlueColor",
    .section = @"Toolbar Items",
    .classes = DPClasses(DPDiaToolbar, DPDiaAddressField),
    .disabledBy = @"hideToolbar",
    .rows = DPHomeButtonRows,
    .install = DPInstallHomeButton,
    .apply = DPApplyHomeButton,
    .verify = DPVerifyHomeButton,
};
