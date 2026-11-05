#import "DeveloperMode.h"

// Arc's banner: a solid color with faint diagonal stripes, laid over the toolbar's own background. Measured from Arc's:
// bands run top-left to bottom-right, half of each 46-point repeat, and are only a hair brighter than the base.
static const CGFloat DPStripePitch = 46, DPStripeSlope = 0.84, DPStripeBrightness = 0.0096, DPStripeSaturation = -0.0127;

// Hues, in turns, for one saturation and brightness taken from Arc's indigo banner (63, 68, 203), so no color outshines it.
static const struct { NSString *name; CGFloat hue; } DPHues[] = {
    {@"Indigo", 0.661}, {@"Blue", 0.6}, {@"Purple", 0.76}, {@"Pink", 0.92}, {@"Red", 0.99},
    {@"Orange", 0.06}, {@"Gold", 0.125}, {@"Green", 0.38}, {@"Teal", 0.5},
};
static const CGFloat DPSaturation = 0.692, DPBrightness = 0.796, DPDarken = 0.1;  // Indigo is Arc's; the others sit darker.

// `light` is for a bar whose controls are dark: a pale version of the color keeps them readable.
static NSColor *DPBannerColor(NSString *name, BOOL light) {
    BOOL indigo = [name isEqualToString:@"Indigo"];
    if ([name isEqualToString:@"Graphite"]) return light ? [NSColor colorWithSRGBRed:0.82 green:0.83 blue:0.86 alpha:1] : [NSColor colorWithSRGBRed:0.22 green:0.23 blue:0.27 alpha:1];
    for (size_t i = 0; i < sizeof DPHues / sizeof *DPHues; i++)
        if ([DPHues[i].name isEqualToString:name])
            return [NSColor colorWithHue:DPHues[i].hue saturation:light ? 0.25 : DPSaturation brightness:light ? 0.97 : DPBrightness - (indigo ? 0 : DPDarken) alpha:1];
    return DPBannerColor(@"Indigo", light);
}

static NSString *const DPHexSetting = @"developerModeColorHex", *const DPNameSetting = @"developerModeColor";

static NSUserDefaults *DPSettings(void) {
    static NSUserDefaults *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return settings;
}

// The picked color, or else the named one an earlier version saved, as it looks for a dark bar.
static NSColor *DPPickedColor(void) {
    NSScanner *scanner = [NSScanner scannerWithString:[[DPSettings() stringForKey:DPHexSetting] ?: @"" stringByReplacingOccurrencesOfString:@"#" withString:@""]];
    unsigned value;
    if (![scanner scanHexInt:&value]) return nil;
    return [NSColor colorWithSRGBRed:(value >> 16 & 0xFF) / 255.0 green:(value >> 8 & 0xFF) / 255.0 blue:(value & 0xFF) / 255.0 alpha:1];
}

static NSColor *DPCurrentColor(BOOL light) { return DPPickedColor() ?: DPBannerColor([DPSettings() stringForKey:DPNameSetting] ?: @"Indigo", light); }

@interface DPBannerColorWell : NSColorWell
@end

@implementation DPBannerColorWell
- (void)pick:(NSColorWell *)well {
    NSColor *srgb = [well.color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: NSColor.blackColor;
    [DPSettings() setObject:[NSString stringWithFormat:@"#%02X%02X%02X", (int)round(srgb.redComponent * 255), (int)round(srgb.greenComponent * 255), (int)round(srgb.blueComponent * 255)] forKey:DPHexSetting];
    DPRelayoutDevMode(NO);
}
@end

NSArray<NSView *> *DPBannerColorRows(void) {
    DPBannerColorWell *well = [DPBannerColorWell new];
    well.color = DPCurrentColor(NO);
    well.target = well;
    well.action = @selector(pick:);
    [well.widthAnchor constraintEqualToConstant:44].active = YES;
    [well.heightAnchor constraintEqualToConstant:24].active = YES;
    NSView *spacer = [NSView new];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *row = [NSStackView stackViewWithViews:@[ [NSTextField labelWithString:@"Banner color"], spacer, well ]];
    return @[ row ];
}

@interface DPDevBanner : NSView
@end

@implementation DPDevBanner

- (NSView *)hitTest:(NSPoint)point { return nil; }
- (void)viewDidChangeEffectiveAppearance { self.needsDisplay = YES; }

- (void)drawRect:(NSRect)dirty {
    BOOL light = [[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameAqua];
    NSColor *color = DPCurrentColor(light);
    CGFloat hue, saturation, brightness;
    [[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] getHue:&hue saturation:&saturation brightness:&brightness alpha:NULL];
    // On the pale banner the bands go slightly darker instead.
    NSColor *band = [NSColor colorWithHue:hue saturation:saturation + (light ? 0 : DPStripeSaturation) brightness:brightness + (light ? -2 : 1) * DPStripeBrightness alpha:1];
    [color setFill];
    NSRectFill(self.bounds);
    [band setFill];
    CGFloat height = NSHeight(self.bounds), run = height / DPStripeSlope;
    for (CGFloat x = -run - DPStripePitch; x < NSWidth(self.bounds); x += DPStripePitch) {
        NSBezierPath *stripe = [NSBezierPath bezierPath];
        [stripe moveToPoint:NSMakePoint(x, height)];
        [stripe lineToPoint:NSMakePoint(x + DPStripePitch / 2, height)];
        [stripe lineToPoint:NSMakePoint(x + DPStripePitch / 2 + run, 0)];
        [stripe lineToPoint:NSMakePoint(x + run, 0)];
        [stripe fill];
    }
}

@end

NSView *DPMakeDevBanner(NSRect frame) {
    NSView *banner = [[DPDevBanner alloc] initWithFrame:frame];
    banner.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    return banner;
}
