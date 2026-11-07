#import "GrainView.h"

static CGImageRef DPGrainImage(NSData *data, size_t size) {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image = CGImageCreate(size, size, 8, 32, size * 4, space,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    return image;
}

static uint32_t DPGrainRandom(uint32_t *state) {
    *state ^= *state << 13; *state ^= *state >> 17; *state ^= *state << 5;
    return *state;
}

CGImageRef DPFineGrainTile(void) {
    static CGImageRef image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enum { size = 192 };
        NSMutableData *data = [NSMutableData dataWithLength:size * size * 4];
        uint8_t *pixels = data.mutableBytes;
        uint32_t random = 0x19643a8d;
        for (NSUInteger i = 0; i < size * size; i++) {
            DPGrainRandom(&random);
            int tone = (int)(random & 255) + (int)((random >> 8) & 255) - 255;
            uint8_t alpha = (uint8_t)abs(tone);
            pixels[4*i] = pixels[4*i+1] = pixels[4*i+2] = tone > 0 ? alpha : 0;
            pixels[4*i+3] = alpha;
        }
        image = DPGrainImage(data, size);
    });
    return image;
}

CGImageRef DPMatteGrainTile(BOOL soft) {
    static CGImageRef image, softened;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enum { size = 256 };
        float *noise = calloc(size * size * 3, sizeof(float));
        uint32_t random = 0x643a8d19;
        for (NSUInteger i = 0; i < size * size * 3; i++) {
            float value = 0;
            for (NSUInteger sample = 0; sample < 6; sample++)
                value += (DPGrainRandom(&random) & 65535) / 65535.0f;
            noise[i] = (value - 3) * M_SQRT2;
        }
        NSMutableData *data = [NSMutableData dataWithLength:size * size * 4];
        uint8_t *pixels = data.mutableBytes;
        const float mean[] = {.800, .800, .804}, deviation[] = {.250, .216, .236};
        const float weight[] = {.2, .8, .2};
        for (NSInteger y = 0; y < size; y++) for (NSInteger x = 0; x < size; x++) {
            NSUInteger pixel = y * size + x;
            for (NSUInteger channel = 0; channel < 3; channel++) {
                float value = 0;
                for (NSInteger dy = -1; dy <= 1; dy++) for (NSInteger dx = -1; dx <= 1; dx++)
                    value += weight[dy+1] * weight[dx+1] * noise[(((y+dy+size)%size)*size+(x+dx+size)%size)*3+channel];
                float tone = fmaxf(0, fminf(1, mean[channel] + deviation[channel] * value / .72f));
                pixels[pixel*4+channel] = (uint8_t)lroundf(tone * 66);
            }
            pixels[pixel*4+3] = 66;
        }
        free(noise);
        image = DPGrainImage(data, size);
        NSMutableData *blurred = [data mutableCopy];
        uint8_t *blur = blurred.mutableBytes;
        const float smoothing[] = {.25, .5, .25};
        for (NSInteger y = 0; y < size; y++) for (NSInteger x = 0; x < size; x++)
            for (NSUInteger channel = 0; channel < 3; channel++) {
                float value = 0;
                for (NSInteger dy = -1; dy <= 1; dy++) for (NSInteger dx = -1; dx <= 1; dx++)
                    value += smoothing[dy+1] * smoothing[dx+1] * pixels[(((y+dy+size)%size)*size+(x+dx+size)%size)*4+channel];
                blur[(y*size+x)*4+channel] = (uint8_t)lroundf(value);
            }
        softened = DPGrainImage(blurred, size);
    });
    return soft ? softened : image;
}
