#import "StdPatch/StdPatch.h"

extern DPPatch DPFixedToolbarColor;
static NSString *const DPBarSetting = @"fixedToolbarColorHex", *const DPFieldSetting = @"fixedToolbarFieldHex";
static NSString *const DPDefaultBar = @"#F5F5F5", *const DPDefaultField = @"#FFFFFF";
static char DPBarFillKey, DPFieldFillKey, DPAppearanceKey, DPLookKey;

static NSUserDefaults *DPSettings(void) {
    static NSUserDefaults *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return settings;
}

static NSColor *DPColorFromHex(NSString *hex, NSString *fallback) {
    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[hex hasPrefix:@"#"] ? [hex substringFromIndex:1] : hex];
    if (![scanner scanHexInt:&value]) return DPColorFromHex(fallback, @"#FFFFFF");
    return [NSColor colorWithSRGBRed:(value >> 16 & 0xFF) / 255.0 green:(value >> 8 & 0xFF) / 255.0 blue:(value & 0xFF) / 255.0 alpha:1];
}

static NSString *DPHexFromColor(NSColor *color) {
    NSColor *srgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: NSColor.whiteColor;
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)round(srgb.redComponent * 255), (int)round(srgb.greenComponent * 255), (int)round(srgb.blueComponent * 255)];
}

static NSColor *DPSavedColor(NSString *setting, NSString *fallback) { return DPColorFromHex([DPSettings() stringForKey:setting] ?: fallback, fallback); }

// Covers a view Dia colors from the page, and lets clicks through to what Dia put under it.
@interface DPFill : NSView
@property NSString *setting, *fallback;
@end

@implementation DPFill
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    self.layer.backgroundColor = DPSavedColor(self.setting, self.fallback).CGColor;
    self.layer.cornerRadius = self.superview.layer.cornerRadius;
    self.layer.masksToBounds = YES;
}
@end

// Dia draws text and icons for the page's color. A light or dark look that matches `color` keeps them readable, and
// nil gives Dia's own back.
static void DPSetLook(NSView *view, NSColor *color) {
    NSArray *saved = DPGet(view, &DPAppearanceKey);
    if (!color) {
        DPSet(view, &DPLookKey, nil);
        if (saved) view.appearance = saved.firstObject == NSNull.null ? nil : saved.firstObject;
        DPSet(view, &DPAppearanceKey, nil);
        return;
    }
    CGFloat luminance = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent;
    NSAppearance *ours = [NSAppearance appearanceNamed:luminance > 0.5 ? NSAppearanceNameAqua : NSAppearanceNameDarkAqua];
    if (!DPGet(view, &DPLookKey)) DPSet(view, &DPAppearanceKey, @[ view.appearance ?: NSNull.null ]);
    DPSet(view, &DPLookKey, ours);
    if (view.appearance != ours) view.appearance = ours;
}

// Dia sets the page's look again as the page changes. Ours stays on, with Dia's kept for when the patch lets go, so the
// text never shows the wrong one for a frame.
static void DPView_setAppearance(NSView *self, SEL _cmd, NSAppearance *appearance) {
    NSAppearance *ours = DPGet(self, &DPLookKey);
    if (ours && appearance != ours) {
        DPSet(self, &DPAppearanceKey, @[ appearance ?: NSNull.null ]);
        appearance = ours;
    }
    DPCallOriginal(DPView_setAppearance, self, appearance);
}

// Puts `fill` just above `below` in `host`, so Developer Mode's banner, which goes above Dia's fill too, covers it.
// Without `below` it goes under every sibling.
static void DPPlaceFill(NSView *host, NSView *below, const void *key, NSString *setting, NSString *fallback, BOOL show) {
    DPFill *fill = DPGet(host, key);
    if (!show) {
        [fill removeFromSuperview];
        DPSet(host, key, nil);
        return;
    }
    if (!fill) {
        fill = [[DPFill alloc] initWithFrame:host.bounds];
        fill.setting = setting;
        fill.fallback = fallback;
        fill.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        DPSet(host, key, fill);
    }
    NSUInteger want = below ? [host.subviews indexOfObject:below] + 1 : 0;
    if (fill.superview != host || [host.subviews indexOfObject:fill] != want) {
        [fill removeFromSuperview];
        if (below) [host addSubview:fill positioned:NSWindowAbove relativeTo:below];
        else [host addSubview:fill positioned:NSWindowBelow relativeTo:host.subviews.firstObject];
    }
    fill.needsDisplay = YES;
}

// The field's rounded pill is the first view inside it.
static NSView *DPPillOf(NSView *bar) {
    NSView *field = DPFindView(bar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAddressField); });
    return field.subviews.firstObject;
}

static void DPApplyToBar(NSView *bar) {
    BOOL on = DPFixedToolbarColor.on;
    NSView *dia = DPSubview(bar, DPDiaColorFill), *pill = DPPillOf(bar);
    DPPlaceFill(bar, dia, &DPBarFillKey, DPBarSetting, DPDefaultBar, on && dia);
    DPPlaceFill(pill ?: bar, nil, &DPFieldFillKey, DPFieldSetting, DPDefaultField, on && pill);
    DPSetLook(bar, on && dia ? DPSavedColor(DPBarSetting, DPDefaultBar) : nil);
    if (pill) DPSetLook(pill.superview, on ? DPSavedColor(DPFieldSetting, DPDefaultField) : nil);
}

static void DPBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPBar_layout, self);
    DPApplyToBar(self);
}

static void DPApplyFixedToolbarColor(DPPatch *patch) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) DPApplyToBar(bar);
}

@interface DPColorRow : NSStackView
@property NSString *setting;
@end

@implementation DPColorRow
- (void)pick:(NSColorWell *)well {
    [DPSettings() setObject:DPHexFromColor(well.color) forKey:self.setting];
    DPApplyFixedToolbarColor(&DPFixedToolbarColor);
}
@end

static NSView *DPColorRowFor(NSString *title, NSString *setting, NSString *fallback) {
    DPColorRow *row = [DPColorRow new];
    row.setting = setting;
    NSColorWell *well = [NSColorWell new];
    well.color = DPSavedColor(setting, fallback);
    well.target = row;
    well.action = @selector(pick:);
    [well.widthAnchor constraintEqualToConstant:44].active = YES;
    [well.heightAnchor constraintEqualToConstant:24].active = YES;
    NSView *spacer = [NSView new];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [row setViews:@[ [NSTextField labelWithString:title], spacer, well ] inGravity:NSStackViewGravityLeading];
    return row;
}

static NSArray<NSView *> *DPFixedToolbarColorRows(void) {
    return @[ DPColorRowFor(@"Toolbar", DPBarSetting, DPDefaultBar), DPColorRowFor(@"Address field", DPFieldSetting, DPDefaultField) ];
}

static void DPInstallFixedToolbarColor(void) {
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPBar_layout);
    DPHook(DPDiaToolbar, @selector(setAppearance:), (IMP)DPView_setAppearance);
    DPHook(DPDiaAddressField, @selector(setAppearance:), (IMP)DPView_setAppearance);
}

static NSString *DPVerifyFixedToolbarColor(DPPatch *patch) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) {
        NSView *pill = DPPillOf(bar);
        BOOL bare = DPGet(bar, &DPBarFillKey) == nil || [DPGet(bar, &DPBarFillKey) superview] != bar;
        BOOL pillBare = !pill || DPGet(pill, &DPFieldFillKey) == nil || [DPGet(pill, &DPFieldFillKey) superview] != pill;
        if (bare == patch->on) return patch->on ? @"toolbar color missing" : @"toolbar color stays";
        if (pill && pillBare == patch->on) return patch->on ? @"address field color missing" : @"address field color stays";
    }
    return nil;
}

DP_PATCH(DPFixedToolbarColor) {
    .key = @"fixedToolbarColor",
    .order = 31,
    .title = @"Fixed Toolbar Color",
    .detail = @"Keep the toolbar and its address field one color you pick instead of changing with each page.",
    .hint = @"The toolbar’s icons and text still adapt to the page, so pick colors they stay readable on.",
    .symbol = @"paintpalette.fill",
    .tint = @"systemOrangeColor",
    .section = @"Toolbar",
    .classes = DPClasses(DPDiaToolbar, DPDiaColorFill, DPDiaAddressField),
    .rows = DPFixedToolbarColorRows,
    .install = DPInstallFixedToolbarColor,
    .apply = DPApplyFixedToolbarColor,
    .verify = DPVerifyFixedToolbarColor,
};
