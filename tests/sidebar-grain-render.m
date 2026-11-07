#import "sidebar-grain-render.h"

extern DPPatch DPKeepWindowsActive;
@interface NSWindow (DPTestAppearance)
- (BOOL)_hasActiveAppearance;
@end

@interface DPObserverGrainView : DPSidebarGrainView
@property NSUInteger notices;
@end
@implementation DPObserverGrainView
- (void)testNotice:(NSNotification *)note { self.notices++; }
@end

double DPTestTextureContrast(NSAppearance *appearance, NSString *texture, double amount, double softness) {
    DPTestTexture = texture;
    DPSidebarGrainView *view = [[DPSidebarGrainView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    view.appearance = appearance;
    [view setGrainAmount:amount softness:softness];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    NSMutableData *overlay = [NSMutableData dataWithLength:200 * 200 * 4];
    CGContextRef context = CGBitmapContextCreate(overlay.mutableBytes, 200, 200, 8, 800, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    [appearance performAsCurrentDrawingAppearance:^{
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
        CGContextScaleCTM(context, 2, 2);
        [view drawRect:view.bounds];
        [NSGraphicsContext restoreGraphicsState];
    }];
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    NSMutableData *composite = [NSMutableData dataWithLength:200 * 200 * 4];
    context = CGBitmapContextCreate(composite.mutableBytes, 200, 200, 8, 800, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    BOOL dark = [[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua];
    CGContextSetRGBFillColor(context, dark ? .10 : .64, dark ? .16 : .76, dark ? .19 : .82, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 200, 200));
    CGContextSetBlendMode(context, [texture isEqual:@"fine"] ? kCGBlendModeNormal : kCGBlendModeMultiply);
    CGContextDrawImage(context, CGRectMake(0, 0, 200, 200), image);
    CGImageRelease(image); CGContextRelease(context); CGColorSpaceRelease(space);
    const uint8_t *pixels = composite.bytes;
    const uint8_t *source = overlay.bytes;
    double base = dark ? .10 : .64;
    BOOL fine = [texture isEqual:@"fine"];
    double sum = 0, square = 0;
    for (NSUInteger i = 0; i < 40000; i++) {
        // Measure before final 8-bit rounding: a dark, almost flat result can
        // straddle a byte boundary and otherwise look noisier numerically.
        double alpha = source[4*i+3] / 255.0, red = source[4*i] / 255.0;
        double value = fine ? base * (1-alpha) + red : base * (1-alpha+red);
        assert(fabs(pixels[4*i] - value*255) <= 2.1);
        sum += value; square += value * value;
        assert(pixels[4*i+3] == 255);
    }
    return sqrt(MAX(0, square/40000 - pow(sum/40000, 2)));
}

void DPTestTextureActivity(NSAppearance *appearance) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ DPKeepWindowsActive.install(); });
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 250)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    window.appearance = appearance;
    DPObserverGrainView *grain = [[DPObserverGrainView alloc] initWithFrame:window.contentView.bounds];
    [NSNotificationCenter.defaultCenter addObserver:grain selector:@selector(testNotice:) name:@"DPGrainFixtureUnrelated" object:nil];
    grain.tracksWindowActivity = YES;
    [window.contentView addSubview:grain];
    [NSNotificationCenter.defaultCenter postNotificationName:@"DPGrainFixtureUnrelated" object:nil];
    assert(grain.notices == 1);
    DPSidebarGrainView *preview = [[DPSidebarGrainView alloc] initWithFrame:NSMakeRect(0, 0, 100, 40)];
    [window.contentView addSubview:preview];
    for (NSString *texture in DPGrainMaterialKeys()) {
        DPTestTexture = texture;
        for (NSNumber *keepActive in @[@YES, @NO, @YES]) {
            DPKeepWindowsActive.on = keepActive.boolValue;
            DPKeepWindowsActive.apply(&DPKeepWindowsActive);
            assert(window._hasActiveAppearance == keepActive.boolValue);
            assert(([[grain valueForKey:@"grainOpacity"] doubleValue] > 0) == keepActive.boolValue);
            [preview setGrainAmount:100 softness:0];
            assert([[preview valueForKey:@"grainOpacity"] doubleValue] > 0);
        }
    }
    [grain removeFromSuperview]; [preview removeFromSuperview];
}
