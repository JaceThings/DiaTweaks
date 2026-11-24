#import "Library.h"
// Reuse Dia's actual profile gradient, never the system's unrelated blue accent.
static NSColor *DPLibraryMostChromatic(CALayer *layer,NSColor *best,CGFloat *chroma) {
    NSArray *colors = [layer isKindOfClass:CAGradientLayer.class] ? [(CAGradientLayer *)layer colors] : @[];
    for (id raw in colors) {
        NSColor *color = [[NSColor colorWithCGColor:(__bridge CGColorRef)raw] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        CGFloat saturation = color.saturationComponent;
        if (saturation > *chroma) { *chroma = saturation; best = color; }
    }
    for (CALayer *child in layer.sublayers) best = DPLibraryMostChromatic(child,best,chroma);
    return best;
}
NSColor *DPLibraryAccentColor(NSWindow *window) {
    NSView *tint = DPFindView(window.contentView.superview,^BOOL(NSView *view) { return DPIsKind(view,DPDiaWindowTint); });
    CGFloat chroma = .02;
    NSColor *accent = DPLibraryMostChromatic(tint.layer,nil,&chroma);
    for (NSView *child in tint.subviews) {
        id raw = DPSwiftValue(child,@"color");
        if (![raw isKindOfClass:NSColor.class]) continue;
        NSColor *color = [raw colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        if (color.saturationComponent > chroma) { accent = color; chroma = color.saturationComponent; }
    }
    // Neutral profiles retain native label contrast instead of gaining blue.
    if (!accent) return NSColor.labelColor;
    BOOL dark = [[window.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua];
    return [NSColor colorWithHue:accent.hueComponent saturation:MAX(.45,accent.saturationComponent) brightness:dark ? .90 : .48 alpha:1];
}
