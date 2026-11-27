#import "Patches/SwipeNewProfile/SwipeNewProfile.h"

// The glow along the sidebar's right edge: half an ellipse centered on the edge, so it bulges in the middle
// and thins out toward the top and bottom. A smooth gradient this faint shows bands on a dark sidebar, so it's
// drawn pixel by pixel with a little noise to dither them away.
static CGImageRef DPCreateEdgeGlow(CGSize size, CGFloat scale, NSColor *ink) {
    size_t width = MAX(1, (size_t)(size.width * scale)), height = MAX(1, (size_t)(size.height * scale));
    NSColor *rgb = ink ?: NSColor.whiteColor;
    CGFloat peak = 0.22;
    uint8_t *pixels = calloc(width * height, 4);
    if (!pixels) return NULL;
    CGFloat rx = width, ry = height * 0.7, cy = height / 2.0;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++) {
            CGFloat dx = (width - x) / rx, dy = (y - cy) / ry, d = sqrt(dx * dx + dy * dy);
            if (d >= 1) continue;
            CGFloat falloff = (1 - d) * (1 - d) * (1 + 2 * d);  // Smooth at both ends.
            CGFloat alpha = MIN(1, MAX(0, peak * falloff + (arc4random_uniform(1000) / 1000.0 - 0.5) / 255.0));
            uint8_t *p = pixels + (y * width + x) * 4;
            p[0] = (uint8_t)lround(rgb.redComponent * alpha * 255);
            p[1] = (uint8_t)lround(rgb.greenComponent * alpha * 255);
            p[2] = (uint8_t)lround(rgb.blueComponent * alpha * 255);
            p[3] = (uint8_t)lround(alpha * 255);
        }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGImageRef image = context ? CGBitmapContextCreateImage(context) : NULL;
    if (context) CGContextRelease(context);
    CGColorSpaceRelease(space);
    free(pixels);
    return image;
}

// Built once per size, scale and light or dark, since drawing it takes a moment.
id DPEdgeGlow(CGFloat width, CGFloat height, CGFloat scale, NSAppearance *appearance) {
    static id cached;
    static NSString *cachedKey;
    NSString *dark = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
    NSString *key = [NSString stringWithFormat:@"%.0f %.0f %.0f %@", width, height, scale, dark];
    if ([key isEqual:cachedKey]) return cached;
    __block NSColor *ink;
    [appearance performAsCurrentDrawingAppearance:^{ ink = [NSColor.labelColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; }];
    cached = (__bridge_transfer id)DPCreateEdgeGlow(CGSizeMake(width, height), scale, ink);
    cachedKey = key;
    return cached;
}
