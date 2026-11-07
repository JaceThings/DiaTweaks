#import "GrainView.h"
#import "TextureNoise.h"

NSArray<NSString *> *DPGrainMaterialKeys(void) {
    return @[@"grain", @"sand", @"tweed", @"denim", @"matte", @"fine"];
}

NSArray<NSString *> *DPGrainMaterialTitles(void) {
    return @[@"Grain", @"Sand", @"Tweed", @"Denim", @"Matte", @"Fine"];
}

BOOL DPIsPatternGrainMaterial(NSString *material) {
    return [@[@"grain", @"sand", @"tweed", @"denim"] containsObject:material];
}

CGFloat DPPatternGrainStrength(NSString *material) {
    // Calibrated linear strength keeps each pattern within its useful contrast range.
    return [@{@"grain": @0.8, @"sand": @0.15, @"tweed": @0.4, @"denim": @0.6}[material] doubleValue];
}

static CGImageRef DPSoftenPatternTile(CGImageRef image) CF_RETURNS_RETAINED {
    NSInteger width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, width, height, 8, width * 4,
        space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return NULL;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    uint8_t *output = data.mutableBytes;
    const CGFloat weight[] = {.25, .5, .25};
    for (NSUInteger pass = 0; pass < 4; pass++) {
        NSData *source = [data copy];
        const uint8_t *pixels = source.bytes;
        for (NSInteger y = 0; y < height; y++) for (NSInteger x = 0; x < width; x++)
            for (NSInteger c = 0; c < 4; c++) {
                CGFloat value = 0;
                for (NSInteger dy = -1; dy <= 1; dy++) for (NSInteger dx = -1; dx <= 1; dx++)
                    value += weight[dy+1] * weight[dx+1] * pixels[(((y+dy+height)%height)*width+(x+dx+width)%width)*4+c];
                output[(y*width+x)*4+c] = lround(value);
            }
    }
    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return result;
}

CGImageRef DPPatternGrainTile(NSString *material, BOOL soft) {
    if (!DPIsPatternGrainMaterial(material)) return NULL;
    static NSDictionary<NSString *, id> *tiles, *softened;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *sharp = [NSMutableDictionary new], *blurred = [NSMutableDictionary new];
        for (NSString *key in @[@"grain", @"sand", @"tweed", @"denim"]) {
            NSMutableData *data = [NSMutableData dataWithLength:200 * 200 * 4];
            DPFillTexturePattern(key, data.mutableBytes);
            CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
            CGImageRef cg = CGImageCreate(200, 200, 8, 32, 800, space,
                kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
            CGDataProviderRelease(provider);
            CGColorSpaceRelease(space);
            if (!cg) continue;
            sharp[key] = CFBridgingRelease(cg);
            CGImageRef smooth = DPSoftenPatternTile(cg);
            if (smooth) blurred[key] = CFBridgingRelease(smooth);
        }
        tiles = [sharp copy];
        softened = [blurred copy];
    });
    return (__bridge CGImageRef)(soft ? softened[material] : tiles[material]);
}
