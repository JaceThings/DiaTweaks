#import "ArcFolderIcons.h"

static char DPOursKey;
static const CGFloat DPDrawnSize = 18, DPSlotSize = 14;  // Dia's 📁 sits in a 14-point slot; Arc's folders are a little bigger.

static NSColor *DPMix(NSColor *a, NSColor *b, CGFloat fraction) {
    return [[a colorUsingColorSpace:NSColorSpace.sRGBColorSpace] blendedColorWithFraction:fraction ofColor:b];
}

static void DPDrawFolder(NSBezierPath *path, NSColor *fill, NSColor *stroke) {
    path.lineWidth = 1.2;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [fill setFill];
    [path fill];
    [stroke setStroke];
    [path stroke];
}

static NSBezierPath *DPBack(CGFloat right, CGFloat bottom) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(1.5, bottom)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(1.5, 13.5) toPoint:NSMakePoint(6, 13.5) radius:1.5];
    [path lineToPoint:NSMakePoint(6, 13.5)];
    [path lineToPoint:NSMakePoint(7.5, 12)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(right, 12) toPoint:NSMakePoint(right, bottom) radius:1.5];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(right, bottom) toPoint:NSMakePoint(1.5, bottom) radius:1.5];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(1.5, bottom) toPoint:NSMakePoint(1.5, 13.5) radius:1.5];
    [path closePath];
    return path;
}

NSImage *DPFolderImage(DPFolderLook look, NSColor *tint, BOOL dark) {
    static NSCache<NSString *, NSImage *> *cache;
    if (!cache) cache = [NSCache new];
    NSColor *rgb = [tint colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: NSColor.systemBlueColor;
    NSString *key = [NSString stringWithFormat:@"%ld %d %.3f %.3f %.3f", (long)look, dark, rgb.redComponent, rgb.greenComponent, rgb.blueComponent];
    // Like Arc: a pale wash of the sidebar's colour, outlined in a deep shade of it. Fixed here, not as the row draws, so
    // hovering or selecting a row never changes them.
    NSColor *fill = dark ? DPMix(rgb, NSColor.blackColor, 0.55) : DPMix(rgb, NSColor.whiteColor, 0.82);
    NSColor *stroke = dark ? DPMix(rgb, NSColor.whiteColor, 0.75) : DPMix(rgb, NSColor.blackColor, 0.5);
    NSImage *image = [cache objectForKey:key];
    if (image) return image;
    image = [NSImage imageWithSize:NSMakeSize(DPDrawnSize, DPDrawnSize) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        NSAffineTransform *scale = [NSAffineTransform transform];
        [scale scaleBy:DPDrawnSize / 16];  // The paths are drawn on a 16-point grid.
        [scale concat];
        if (look != DPFolderOpen) {
            DPDrawFolder(DPBack(14.5, 2.5), fill, stroke);
            NSBezierPath *line = [NSBezierPath bezierPath];
            [line moveToPoint:NSMakePoint(1.5, 10.5)];
            [line lineToPoint:NSMakePoint(14.5, 10.5)];
            DPDrawFolder(line, NSColor.clearColor, stroke);
            if (look == DPFolderPeeked) {
                [stroke setFill];
                for (CGFloat x = 5; x <= 11; x += 3) [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x - 0.9, 5.6, 1.8, 1.8)] fill];
            }
            return YES;
        }
        DPDrawFolder(DPBack(13, 2.5), fill, stroke);
        NSBezierPath *flap = [NSBezierPath bezierPath];  // The front, tipped forward.
        [flap moveToPoint:NSMakePoint(4, 9)];
        [flap lineToPoint:NSMakePoint(15.5, 9)];
        [flap lineToPoint:NSMakePoint(13, 2.5)];
        [flap lineToPoint:NSMakePoint(1.5, 2.5)];
        [flap closePath];
        DPDrawFolder(flap, fill, stroke);
        return YES;
    }];
    // Laid out in Dia's slot but drawn past it, as Dia's own emoji are.
    CGFloat inset = (DPDrawnSize - DPSlotSize) / 2;
    image.alignmentRect = NSMakeRect(inset, inset, DPSlotSize, DPSlotSize);
    image.accessibilityDescription = look == DPFolderOpen ? @"Open folder" : look == DPFolderPeeked ? @"Folder, showing its active tab" : @"Folder";
    DPSet(image, &DPOursKey, @YES);
    [cache setObject:image forKey:key];
    return image;
}

BOOL DPIsFolderImage(NSImage *image) { return image && DPGet(image, &DPOursKey) != nil; }

// The sidebar's colour: the last stop of the gradient Dia lays over the window for the profile's theme. Only the window's
// own tint view, not the selected tab's copy deeper down, whose plain fill is white.
NSColor *DPSidebarTint(NSWindow *window, BOOL *dark) {
    NSView *tint = nil;
    for (NSView *sub in window.contentView.superview.subviews)
        for (NSView *inner in sub.subviews) if (!tint && DPIsKind(inner, DPDiaWindowTint)) tint = inner;
    *dark = [tint.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
    for (NSView *fill in tint.subviews)
        for (CALayer *layer in fill.layer.sublayers) {
            id last = [layer isKindOfClass:CAGradientLayer.class] ? [(CAGradientLayer *)layer colors].lastObject : nil;
            if (last && CGColorGetAlpha((__bridge CGColorRef)last) > 0.01) return [[NSColor colorWithCGColor:(__bridge CGColorRef)last] colorWithAlphaComponent:1];
        }
    return NSColor.controlAccentColor;
}
