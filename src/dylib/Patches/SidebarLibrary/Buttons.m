#import "Library.h"
@interface DPLibraryCategoryCell : NSButtonCell @end
@implementation DPLibraryCategoryCell
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view {
    // Borderless NSButton's image-above layout hugs its native cell edge.
    // Center the icon/label group together, with equal outer vertical padding.
    NSColor *color = NSColor.labelColor;
    BOOL label = self.title.length > 0;
    BOOL entry=[view.identifier hasPrefix:@"DiaTweaks.SidebarLibrary."] && [view.identifier hasSuffix:@"Button"];
    CGFloat iconSize = label ? 22 : entry ? 20 : 16;
    CGFloat top = NSMidY(frame)-(label ? 22 : iconSize/2);
    NSRect icon = NSMakeRect(NSMidX(frame)-iconSize/2,top,iconSize,iconSize);
    NSRect text = NSMakeRect(NSMinX(frame)+2,top+29,NSWidth(frame)-4,16);
    if (!view.isFlipped) {
        icon.origin.y = NSMaxY(frame)-(NSMinY(icon)-NSMinY(frame))-NSHeight(icon);
        text.origin.y = NSMaxY(frame)-(NSMinY(text)-NSMinY(frame))-NSHeight(text);
    }
    NSColor *iconColor = label ? DPLibraryAccentColor(view.window) : ([(NSButton *)view contentTintColor] ?: NSColor.secondaryLabelColor);
    NSImage *image = [self.image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[iconColor]]];
    NSSize size=image.size;
    if (size.width>0 && size.height>0) {
        CGFloat fit=MIN(NSWidth(icon)/size.width,NSHeight(icon)/size.height);
        icon=NSMakeRect(NSMidX(icon)-size.width*fit/2,NSMidY(icon)-size.height*fit/2,size.width*fit,size.height*fit);
    }
    [image drawInRect:icon fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:self.highlighted ? .65 : 1 respectFlipped:YES hints:nil];
    if (label) {
        NSMutableParagraphStyle *style = [NSMutableParagraphStyle new]; style.alignment = NSTextAlignmentCenter;
        style.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.title drawInRect:text withAttributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:style}];
    }
}
@end
NSButton *DPLibraryMakeButton(NSString *title, NSString *symbol, id target, SEL action) {
    NSButton *button = [DPLibraryButton buttonWithTitle:title target:target action:action];
    button.bordered = NO; button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    button.image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:19 weight:NSFontWeightRegular]];
    button.imagePosition = title.length ? NSImageAbove : NSImageOnly;
    button.contentTintColor = NSColor.labelColor;
    button.accessibilityLabel = title.length ? title : @"Sidebar Library";
    button.wantsLayer = YES; button.layer.cornerRadius = 9;
    return button;
}
@implementation DPLibraryButton
+ (Class)cellClass { return DPLibraryCategoryCell.class; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:self.tracking];
    [self dpLibraryUpdatePointerHover];
}
- (void)dpLibraryUpdatePointerHover { BOOL inside=DPLibraryPointerInside(self); if(self.hovered!=inside) { self.hovered=inside; self.needsDisplay=YES; } }
- (void)mouseDown:(NSEvent *)event {
    self.hovered = NO; self.needsDisplay = YES; [super mouseDown:event];
    self.hovered = NO; self.needsDisplay = YES;
}
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; self.hovered = NO; self.needsDisplay = YES; }
- (void)mouseEntered:(NSEvent *)event { [self dpLibraryUpdatePointerHover]; }
- (void)mouseExited:(NSEvent *)event { [self dpLibraryUpdatePointerHover]; }
- (void)drawRect:(NSRect)rect {
    if ((self.hovered || (self.state && [self.identifier isEqual:@"persistentSelection"])) && ![self.identifier isEqual:@"category"]) {
        BOOL horizontal=[self.identifier isEqual:@"DiaTweaks.SidebarLibrary.HorizontalButton"];
        NSColor *hover=horizontal ? [NSColor.whiteColor colorWithAlphaComponent:.14] : [NSColor.labelColor colorWithAlphaComponent:self.state ? .10 : .06];
        [hover setFill];
        [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:11 yRadius:11] fill];
    }
    [super drawRect:rect];
}
@end

@interface DPLibraryRail : NSView @end
@implementation DPLibraryRail
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
    [[NSColor.labelColor colorWithAlphaComponent:.045] setFill]; NSRectFill(self.bounds);
}
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; self.needsDisplay = YES; }
@end

void DPLibraryResetUtilityHover(NSWindow *window) {
    DPFindView(window.contentView,^BOOL(NSView *view) {
        if ([view isKindOfClass:DPLibraryButton.class] && ![view.identifier isEqual:@"category"]) {
            DPLibraryButton *button=(id)view; button.hovered=NO; [button.cell setHighlighted:NO]; button.needsDisplay=YES;
        } return NO;
    });
}
