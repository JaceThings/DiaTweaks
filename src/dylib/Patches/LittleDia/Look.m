#import "LittleDia.h"
#import <objc/message.h>

// A hairline under the bar, between it and the page, as in Dia's main window.
@interface DPBarDivider : NSView
@end

@implementation DPBarDivider
- (BOOL)mouseDownCanMoveWindow { return YES; }
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (void)drawRect:(NSRect)rect {
    [[NSColor.labelColor colorWithAlphaComponent:0.1] setFill];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
}
@end

NSView *DPMakeDivider(void) { return [DPBarDivider new]; }

// The page's background, or failing that its theme-color. Chromium has neither for some pages: nil.
static NSColor *DPPageColor(id page) {
    id root = [page respondsToSelector:@selector(rootBackgroundColor)] ? ((id (*)(id, SEL))objc_msgSend)(page, @selector(rootBackgroundColor)) : nil;
    float (*part)(id, SEL) = (void *)objc_msgSend;
    if ([root respondsToSelector:@selector(a)] && part(root, @selector(a)) > 0.99)
        return [NSColor colorWithSRGBRed:part(root, @selector(r)) green:part(root, @selector(g)) blue:part(root, @selector(b)) alpha:1];
    id theme = [page respondsToSelector:@selector(themeColor)] ? ((id (*)(id, SEL))objc_msgSend)(page, @selector(themeColor)) : nil;
    unsigned char (*byte)(id, SEL) = (void *)objc_msgSend;
    if ([theme respondsToSelector:@selector(a)] && byte(theme, @selector(a)) == 255)
        return [NSColor colorWithSRGBRed:byte(theme, @selector(r)) / 255.0 green:byte(theme, @selector(g)) / 255.0 blue:byte(theme, @selector(b)) / 255.0 alpha:1];
    return nil;
}

static char DPColorKey;

// The bar takes the page's colour, with light or dark text to suit. No page puts Dia's own back.
void DPMatchPage(NSView *row, id page) {
    NSColor *color = DPPageColor(page);
    if ([DPGet(row, &DPColorKey) isEqual:color] || (!color && !DPGet(row, &DPColorKey))) return;
    DPSet(row, &DPColorKey, color);
    row.wantsLayer = YES;
    row.layer.backgroundColor = color.CGColor;
    CGFloat luminance = 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent;
    row.appearance = !color ? nil : [NSAppearance appearanceNamed:luminance > 0.55 ? NSAppearanceNameAqua : NSAppearanceNameDarkAqua];
}
