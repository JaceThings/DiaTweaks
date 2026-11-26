#import "CustomProfileColor.h"

static char DPAppearanceKey;

static CGFloat DPLinear(CGFloat v) { return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4); }

// What the wash looks like over the window's own background, so a pale color at low alpha over dark mode still counts as dark.
static CGFloat DPShownLuminance(NSColor *color, NSAppearance *appearance) {
    __block NSColor *under;
    [appearance performAsCurrentDrawingAppearance:^{ under = [NSColor.windowBackgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; }];
    NSColor *c = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if (!c || !under) return 0.5;
    CGFloat a = c.alphaComponent;
    CGFloat r = c.redComponent * a + under.redComponent * (1 - a);
    CGFloat g = c.greenComponent * a + under.greenComponent * (1 - a);
    CGFloat b = c.blueComponent * a + under.blueComponent * (1 - a);
    return 0.2126 * DPLinear(r) + 0.7152 * DPLinear(g) + 0.0722 * DPLinear(b);
}

static id DPOrNull(id value) { return value ?: NSNull.null; }
static id DPOrNil(id value) { return value == NSNull.null ? nil : value; }
static BOOL DPSame(NSAppearance *a, NSAppearance *b) { return a == b || [a.name isEqualToString:b.name]; }

// Dia's appearance for the window, unless Dia changed it after we did. Windows usually have none (nil).
static NSAppearance *DPDiasAppearance(NSWindow *window) {
    NSArray *saved = DPGet(window, &DPAppearanceKey);
    return saved && DPSame(DPOrNil(saved[1]), window.appearance) ? DPOrNil(saved[0]) : window.appearance;
}

void DPApplyContrast(NSWindow *window) {
    if (!window) return;
    NSAppearance *dia = DPDiasAppearance(window), *ours = dia;
    NSColor *custom = DPCustomColor(DPCurrentSpaceID(window));
    if (custom) {
        // Judge against Dia's appearance, not ours: a window with none follows the app's.
        // Above 0.179, black text has more contrast than white (WCAG).
        BOOL light = DPShownLuminance(custom, dia ?: NSApp.effectiveAppearance) > 0.179;
        ours = [NSAppearance appearanceNamed:light ? NSAppearanceNameAqua : NSAppearanceNameDarkAqua];
    }
    DPSet(window, &DPAppearanceKey, @[ DPOrNull(dia), DPOrNull(ours) ]);
    if (!DPSame(window.appearance, ours)) window.appearance = ours;
}
