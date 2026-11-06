#import "SidebarGrain.h"

NSColor *DPGrainPreviewColor(NSWindow *window, NSAppearance *appearance) {
    NSView *sidebar = nil;
    NSArray<NSWindow *> *windows = window ? @[window] : NSApp.orderedWindows;
    for (NSWindow *candidate in windows) {
        for (NSView *view in DPGrainSidebars) {
            if (view.window == candidate && !view.hiddenOrHasHiddenAncestor &&
                DPSubview(view, DPDiaSidebarFooter)) {
                sidebar = view;
                break;
            }
        }
        if (sidebar) break;
    }

    __block NSColor *base;
    [appearance performAsCurrentDrawingAppearance:^{ base = [NSColor.windowBackgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; }];
    if (!base) base = [NSColor colorWithSRGBRed:0.5 green:0.5 blue:0.5 alpha:1];
    NSView *tint = nil;
    for (NSView *view in sidebar.window.contentView.superview.subviews) {
        if (DPIsKind(view, DPDiaWindowTint)) { tint = view; break; }
        tint = DPSubview(view, DPDiaWindowTint);
        if (tint) break;
    }
    if (!tint || tint.hiddenOrHasHiddenAncestor || !tint.layer) return base;

    NSPoint point = [sidebar convertPoint:NSMakePoint(NSMidX(sidebar.bounds), NSMidY(sidebar.bounds)) toView:tint];
    if (!NSPointInRect(point, tint.bounds)) return base;

    // Sample only Dia's tint layer. This also handles a gradient without capturing page content.
    uint8_t pixel[4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) return base;
    CGContextTranslateCTM(context, -floor(point.x), -floor(point.y));
    [tint.layer renderInContext:context];
    CGContextRelease(context);

    CGFloat alpha = pixel[3] / 255.0 * tint.alphaValue;
    if (alpha == 0) return base;
    NSColor *color = [NSColor colorWithSRGBRed:(CGFloat)pixel[0] / pixel[3]
        green:(CGFloat)pixel[1] / pixel[3] blue:(CGFloat)pixel[2] / pixel[3] alpha:1];
    return [base blendedColorWithFraction:alpha ofColor:color];
}
