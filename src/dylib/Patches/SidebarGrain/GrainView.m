#import "GrainView.h"

static CGImageRef DPGrainTile(void) {
    static CGImageRef image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enum { size = 192 };
        NSMutableData *data = [NSMutableData dataWithLength:size * size * 4];
        uint8_t *pixels = data.mutableBytes;
        uint32_t random = 0x19643a8d;
        for (NSUInteger i = 0; i < size * size; i++) {
            random ^= random << 13;
            random ^= random >> 17;
            random ^= random << 5;
            int tone = (int)(random & 255) + (int)((random >> 8) & 255) - 255;
            uint8_t alpha = (uint8_t)abs(tone);
            pixels[4*i] = pixels[4*i+1] = pixels[4*i+2] = tone > 0 ? alpha : 0;
            pixels[4*i+3] = alpha;
        }
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        image = CGImageCreate(size, size, 8, 32, size * 4, space,
            (CGBitmapInfo)kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
        CGColorSpaceRelease(space);
        CGDataProviderRelease(provider);
    });
    return image;
}

@implementation DPSidebarGrainView {
    CGFloat _grainOpacity, _softness;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.wantsLayer = YES;
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    return self;
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)setGrainAmount:(double)amount softness:(double)softness {
    // Give the lower half of the slider more room for subtle adjustments.
    CGFloat opacity = (0.66 * pow(0.60, 1.35)) * pow(MAX(0, MIN(100, amount)) / 100, 1.35);
    CGFloat soft = MAX(0, MIN(100, softness)) / 100;
    if (_grainOpacity == opacity && _softness == soft) return;
    _softness = soft;
    _grainOpacity = opacity;
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_grainOpacity == 0) return;
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);
    CGFloat radius = self.layer.cornerRadius;
    if (radius > 0) {
        CGPathRef clip = CGPathCreateWithRoundedRect(self.bounds, radius, radius, NULL);
        CGContextAddPath(context, clip);
        CGPathRelease(clip);
        CGContextClip(context);
    } else {
        CGContextClipToRect(context, self.bounds);
    }
    CGContextSetAlpha(context, _grainOpacity * (1 - 0.45 * _softness));
    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    CGContextDrawTiledImage(context, CGRectMake(0, 0, 120 + 24 * _softness, 120 + 24 * _softness), DPGrainTile());
    CGContextRestoreGState(context);
}

@end
