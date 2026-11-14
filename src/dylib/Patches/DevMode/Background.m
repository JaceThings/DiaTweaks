#import "DevMode.h"

static NSString *const DPBackgroundKey = @"portraitCaptureBackground", *const DPHueKey = @"portraitCaptureHue";

static NSUserDefaults *DPPortraitDefaults(void) {
    static NSUserDefaults *defaults;
    if (!defaults) defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    return defaults;
}

DPPortraitBackground DPPortraitChoice(void) {
    NSInteger saved = [DPPortraitDefaults() integerForKey:DPBackgroundKey];
    return saved == DPPortraitWallpaper || saved == DPPortraitBlack ? saved : DPPortraitHue;
}

CGFloat DPPortraitHueValue(void) {
    id saved = [DPPortraitDefaults() objectForKey:DPHueKey];
    return saved ? [saved doubleValue] : 0.85;
}

void DPSetPortraitStyle(DPPortraitBackground background, CGFloat hue) {
    [DPPortraitDefaults() setInteger:background forKey:DPBackgroundKey];
    [DPPortraitDefaults() setDouble:hue forKey:DPHueKey];
}

NSColor *DPHueColor(CGFloat hue) {
    static const unsigned stops[] = { 0xFAD4DD, 0xF06BB4, 0xF43F3F, 0xF7931E, 0xF5D90A, 0x3DDC6B, 0x22C3E6, 0x4F6FE0 };
    const NSUInteger count = sizeof(stops) / sizeof(*stops);
    CGFloat position = MAX(0, MIN(1, hue)) * (count - 1);
    NSUInteger i = MIN((NSUInteger)position, count - 2);
    CGFloat t = position - i;
    CGFloat (^channel)(int) = ^CGFloat(int shift) {
        return (((stops[i] >> shift) & 0xFF) * (1 - t) + ((stops[i + 1] >> shift) & 0xFF) * t) / 255;
    };
    return [NSColor colorWithSRGBRed:channel(16) green:channel(8) blue:channel(0) alpha:1];
}

static void DPDrawGradient(CGContextRef context, NSArray<NSColor *> *colors, CGPoint from, CGPoint to, CGFloat radius) {
    NSMutableArray *cgColors = [NSMutableArray new];
    for (NSColor *color in colors) [cgColors addObject:(__bridge id)color.CGColor];
    CGGradientRef gradient = CGGradientCreateWithColors(NULL, (__bridge CFArrayRef)cgColors, NULL);
    if (radius > 0) CGContextDrawRadialGradient(context, gradient, from, 0, from, radius, kCGGradientDrawsAfterEndLocation);
    else CGContextDrawLinearGradient(context, gradient, from, to, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
}

void DPFillGradient(CGContextRef context, CGRect rect, NSColor *color) {
    CGPoint topLeft = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)), bottomRight = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
    DPDrawGradient(context, @[ [color blendedColorWithFraction:0.2 ofColor:NSColor.whiteColor], [color blendedColorWithFraction:0.3 ofColor:NSColor.blackColor] ], topLeft, bottomRight, 0);
    NSColor *glow = [color blendedColorWithFraction:0.55 ofColor:NSColor.whiteColor];
    DPDrawGradient(context, @[ [glow colorWithAlphaComponent:0.6], [glow colorWithAlphaComponent:0] ], topLeft, topLeft, MAX(rect.size.width, rect.size.height) * 0.7);
}

void DPFillBlack(CGContextRef context, CGRect rect) {
    CGContextSetFillColorWithColor(context, NSColor.blackColor.CGColor);
    CGContextFillRect(context, rect);
}

BOOL DPFillWallpaper(CGContextRef context, CGRect rect, NSWindow *window) {
    NSScreen *screen = window.screen ?: NSScreen.mainScreen;
    NSImage *wallpaper = [[NSImage alloc] initWithContentsOfURL:[NSWorkspace.sharedWorkspace desktopImageURLForScreen:screen]];
    if (!wallpaper.isValid || wallpaper.size.width <= 0) return NO;
    NSRect desk = screen.frame, area = NSIntersectionRect(window.frame, desk);
    if (NSIsEmptyRect(area)) area = desk;
    CGFloat aspect = rect.size.width / rect.size.height;
    if (area.size.width / area.size.height > aspect) area = NSInsetRect(area, (area.size.width - area.size.height * aspect) / 2, 0);
    else area = NSInsetRect(area, 0, (area.size.height - area.size.width / aspect) / 2);
    CGFloat fill = MAX(desk.size.width / wallpaper.size.width, desk.size.height / wallpaper.size.height);
    NSRect drawn = NSMakeRect(NSMidX(desk) - wallpaper.size.width * fill / 2, NSMidY(desk) - wallpaper.size.height * fill / 2, wallpaper.size.width * fill, wallpaper.size.height * fill);
    CGFloat k = rect.size.width / area.size.width;
    CGRect target = CGRectMake(rect.origin.x + (drawn.origin.x - area.origin.x) * k, rect.origin.y + (drawn.origin.y - area.origin.y) * k, drawn.size.width * k, drawn.size.height * k);
    CGImageRef image = [wallpaper CGImageForProposedRect:NULL context:nil hints:nil];
    if (!image) return NO;
    CGContextSaveGState(context);
    CGContextClipToRect(context, rect);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, target, image);
    CGContextRestoreGState(context);
    return YES;
}
