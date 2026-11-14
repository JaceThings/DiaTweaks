#import "CustomProfileColor.h"

static NSString *const DPColorsKey = @"profileColors";
static NSUserDefaults *DPColorDefaults;
static char DPDiaColorKey;

NSColor *DPCustomColor(NSString *spaceID) {
    if (!DPCustomProfileColor.on || !spaceID) return nil;
    NSArray<NSNumber *> *c = [DPColorDefaults dictionaryForKey:DPColorsKey][spaceID];
    if (![c isKindOfClass:NSArray.class] || c.count != 4) return nil;
    return [NSColor colorWithSRGBRed:c[0].doubleValue green:c[1].doubleValue blue:c[2].doubleValue alpha:c[3].doubleValue];
}

void DPSetCustomColor(NSString *spaceID, NSColor *color) {
    if (!spaceID) return;
    NSMutableDictionary *all = [[DPColorDefaults dictionaryForKey:DPColorsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSColor *c = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    all[spaceID] = c ? @[ @(c.redComponent), @(c.greenComponent), @(c.blueComponent), @(c.alphaComponent) ] : nil;
    [DPColorDefaults setObject:all forKey:DPColorsKey];
    DPRepaintProfileColors();
}

NSString *DPSpaceIDOfItem(NSView *item) {
    NSDictionary *views = DPSwiftValue(item.superview, @"itemViews");
    for (id key in views) if (views[key] == item) return [key description];
    return nil;
}

// The selected profile in the sidebar's switcher, or the focused dot when tabs are at the top.
NSString *DPCurrentSpaceID(NSWindow *window) {
    for (NSView *item in DPFindViews(DPDiaSpaceSwitcherItem))
        if (item.window == window && [DPSwiftValue(item, @"isSelected") boolValue]) return DPSpaceIDOfItem(item);
    for (NSView *dot in DPFindViews(DPDiaPageIndicatorDot)) {
        id focused = dot.window == window ? DPSwiftValue(dot.superview, @"focusedSpaceID") : nil;
        if (focused) return [focused description];
    }
    return nil;
}

// The wash is the BackgroundColorView in the window's tint; the theme frame is above contentView, so search from there.
static BOOL DPIsWash(NSView *view) { return DPIsKind(view.superview, DPDiaWindowTint); }

static void DPCollectWashes(NSView *view, NSMutableArray<NSView *> *found) {
    if (DPIsKind(view, DPDiaColorView) && DPIsWash(view)) [found addObject:view];
    for (NSView *sub in view.subviews) DPCollectWashes(sub, found);
}

static NSArray<NSView *> *DPWashes(void) {
    NSMutableArray *found = [NSMutableArray array];
    for (NSWindow *window in NSApp.windows)
        if (window.isVisible && window.contentView.superview) DPCollectWashes(window.contentView.superview, found);
    return found;
}

NSColor *DPDiaProfileColor(NSWindow *window) {
    for (NSView *wash in DPWashes()) if (wash.window == window && DPGet(wash, &DPDiaColorKey)) return DPGet(wash, &DPDiaColorKey);
    return nil;
}

static void DPWash_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPWash_updateLayer, self);
    if (!DPIsWash(self) || !self.layer.backgroundColor) return;
    DPSet(self, &DPDiaColorKey, [NSColor colorWithCGColor:self.layer.backgroundColor]);
    NSColor *custom = DPCustomColor(DPCurrentSpaceID(self.window));
    if (custom) self.layer.backgroundColor = custom.CGColor;
}

// Switching profiles may keep the same Dia color, so the wash wouldn't redraw on its own.
static void DPSwitcherItem_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSwitcherItem_layout, self);
    if (![DPSwiftValue(self, @"isSelected") boolValue]) return;
    for (NSView *wash in DPWashes()) if (wash.window == self.window) wash.needsDisplay = YES;
}

void DPRepaintProfileColors(void) {
    for (NSView *wash in DPWashes()) wash.needsDisplay = YES;
}

// Our menu items come and go as the menu opens.
static void DPApplyCustomProfileColor(DPPatch *patch) { DPRepaintProfileColors(); }

static NSString *DPVerifyCustomProfileColor(DPPatch *patch) {
    for (NSView *wash in DPWashes()) {
        if (wash.hiddenOrHasHiddenAncestor) continue;
        NSColor *custom = DPCustomColor(DPCurrentSpaceID(wash.window)), *dia = DPGet(wash, &DPDiaColorKey);
        CGColorRef shown = wash.layer.backgroundColor;
        if (custom && !CGColorEqualToColor(shown, custom.CGColor)) return @"profile color not replaced";
        if (!custom && dia && !CGColorEqualToColor(shown, dia.CGColor)) return @"Dia's profile color not restored";
    }
    return nil;
}

static void DPInstallCustomProfileColor(void) {
    DPColorDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    DPHook(DPDiaColorView, @selector(updateLayer), (IMP)DPWash_updateLayer);
    DPHook(DPDiaSpaceSwitcherItem, @selector(layout), (IMP)DPSwitcherItem_layout);
    DPInstallProfileColorMenu();
}

DP_PATCH(DPCustomProfileColor) {
    .key = @"customProfileColor",
    .order = 79,
    .title = @"Custom Profile Color",
    .detail = @"Pick any color and transparency for a profile from a color wheel. Right-click the sidebar › Edit Profile › Custom Color…",
    .symbol = @"paintpalette.fill",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaColorView, DPDiaWindowTint, DPDiaSpaceSwitcherItem),
    .install = DPInstallCustomProfileColor,
    .apply = DPApplyCustomProfileColor,
    .verify = DPVerifyCustomProfileColor,
};
