#import "Patches/Peek/Peek.h"

// Arc's round controls take the first click, so one press on them works straight away.
@interface DPPeekButton : NSButton
@end

@implementation DPPeekButton
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer { self.layer.backgroundColor = [NSColor colorWithWhite:0.08 alpha:self.isHighlighted ? 0.7 : 0.9].CGColor; }
@end

// Top to bottom: close, open as tab, open in split view. Each button's tag is the exit it stands for. Fixed frames
// rather than a stack view, which squeezed the circles out of shape.
NSView *DPPeekControls(id target, SEL action) {
    static const CGFloat side = 28, gap = 8;
    NSArray *specs = @[@[@"xmark", @"Close Peek"], @[@"arrow.up.left.and.arrow.down.right", @"Open as Tab"], @[@"rectangle.split.2x1", @"Open in Split View"]];
    NSView *controls = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, side, specs.count * side + (specs.count - 1) * gap)];
    for (NSUInteger i = 0; i < specs.count; i++) {
        DPPeekButton *button = [DPPeekButton buttonWithImage:[NSImage imageWithSystemSymbolName:specs[i][0] accessibilityDescription:specs[i][1]]
                                                      target:target action:action];
        button.tag = i;
        button.bordered = NO;
        button.toolTip = specs[i][1];
        button.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightBold];
        button.contentTintColor = NSColor.whiteColor;
        button.imagePosition = NSImageOnly;
        button.wantsLayer = YES;
        button.layer.cornerRadius = side / 2;
        button.layer.cornerCurve = kCACornerCurveCircular;
        button.frame = NSMakeRect(0, (specs.count - 1 - i) * (side + gap), side, side);
        [controls addSubview:button];
    }
    return controls;
}
