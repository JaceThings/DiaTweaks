#import "GrainView.h"

BOOL DPGrainDarkAppearance(NSAppearance *appearance) {
    return [[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]]
        isEqual:NSAppearanceNameDarkAqua];
}

CGImageRef DPGrainAppearanceTile(NSString *material, BOOL soft, BOOL dark) {
    CGImageRef image = DPIsPatternGrainMaterial(material) ? DPPatternGrainTile(material, soft) : DPMatteGrainTile(soft);
    if (!dark || !image) return image;
    static NSMutableDictionary<NSString *, id> *tiles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ tiles = [NSMutableDictionary new]; });
    NSString *key = [NSString stringWithFormat:@"%@-%d", material, soft];
    if (!tiles[key]) {
        size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context = CGBitmapContextCreate(data.mutableBytes, width, height, 8, width * 4, space,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space);
        if (!context) return image;
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        uint8_t *pixels = data.mutableBytes;
        // Invert premultiplied tones so Screen lifts dark details by the same
        // amount that Multiply darkens them in light mode, without a pale wash.
        for (size_t i = 0; i < width * height; i++) for (NSUInteger c = 0; c < 3; c++)
            pixels[i*4+c] = pixels[i*4+3] - MIN(pixels[i*4+3], pixels[i*4+c]);
        CGImageRef inverted = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        if (inverted) tiles[key] = CFBridgingRelease(inverted);
    }
    return (__bridge CGImageRef)tiles[key] ?: image;
}
