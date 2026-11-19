#import "DevMode.h"

static const CGFloat DPPageWidth = 4320, DPBand = 17, DPRadius = 16;
const CGFloat DPPortraitInset = 384 / 4320.0, DPPortraitAspect = 3224 / 5088.0;

static CGPathRef DPRoundedRect(CGRect rect, CGFloat radius) {
    return CGPathCreateWithRoundedRect(rect, radius, radius, NULL);
}

static void DPFillBackground(CGContextRef context, CGRect rect, NSWindow *window) {
    DPPortraitBackground choice = DPPortraitChoice();
    if (choice == DPPortraitWallpaper && DPFillWallpaper(context, rect, window)) return;
    if (choice == DPPortraitBlack) return DPFillBlack(context, rect);
    DPFillGradient(context, rect, DPHueColor(DPPortraitHueValue()));
}

static void DPDrawFrame(CGContextRef context, CGRect pageRect, CGFloat unit) {
    CGFloat band = DPBand * unit, radius = DPRadius * unit;
    CGRect outer = CGRectInset(pageRect, -band, -band);
    CGPathRef outerPath = DPRoundedRect(outer, radius);
    CGContextAddPath(context, outerPath);
    CGContextSetFillColorWithColor(context, [NSColor colorWithWhite:1 alpha:0.5].CGColor);
    CGContextFillPath(context);
    CGPathRef edge = DPRoundedRect(CGRectInset(outer, unit, unit), radius - unit);
    CGContextAddPath(context, edge);
    CGContextSetStrokeColorWithColor(context, [NSColor colorWithWhite:1 alpha:0.85].CGColor);
    CGContextSetLineWidth(context, MAX(1, 2 * unit));
    CGContextStrokePath(context);
    CGPathRelease(outerPath);
    CGPathRelease(edge);
}

NSImage *DPPortraitImage(NSImage *page, NSWindow *window, CGFloat width, CGFloat aspect) {
    CGImageRef pageImage = [page CGImageForProposedRect:NULL context:nil hints:nil];
    if (!pageImage) return nil;
    CGFloat pageWidth = CGImageGetWidth(pageImage), pageHeight = CGImageGetHeight(pageImage);
    CGFloat unit = pageWidth / DPPageWidth, inset = DPPortraitInset * pageWidth;
    CGSize size = CGSizeMake(pageWidth + 2 * inset, pageHeight + 2 * inset);
    if (aspect > 0) size = size.height / size.width > aspect ? CGSizeMake(size.height / aspect, size.height) : CGSizeMake(size.width, size.width * aspect);
    CGFloat scale = width > 0 ? width / size.width : 1;
    size_t canvasWidth = (size_t)round(size.width * scale), canvasHeight = (size_t)round(size.height * scale);
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, canvasWidth, canvasHeight, 8, 0, CGImageGetColorSpace(pageImage) ?: srgb, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(srgb);
    if (!context) return nil;
    CGContextScaleCTM(context, scale, scale);
    CGRect canvas = CGRectMake(0, 0, size.width, size.height);
    CGRect pageRect = CGRectMake((size.width - pageWidth) / 2, (size.height - pageHeight) / 2, pageWidth, pageHeight);
    DPFillBackground(context, canvas, window);
    DPDrawFrame(context, pageRect, unit);
    CGPathRef clip = DPRoundedRect(pageRect, (DPRadius - 4) * unit);
    CGContextAddPath(context, clip);
    CGContextClip(context);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, pageRect, pageImage);
    CGPathRelease(clip);
    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    NSImage *image = [[NSImage alloc] initWithCGImage:result size:NSMakeSize(canvasWidth, canvasHeight)];
    CGImageRelease(result);
    return image;
}
