#import "AddButton.h"
#import "Patches/SidebarLibrary/Library.h"
@implementation DPTaskAddButton
- (void)drawRect:(NSRect)rect {
    NSColor *accent=DPLibraryAccentColor(self.window);
    NSColor *rgb=[accent colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    CGFloat light=rgb ? .2126*rgb.redComponent+.7152*rgb.greenComponent+.0722*rgb.blueComponent : .3;
    [[accent colorWithAlphaComponent:self.enabled ? 1 : .22] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,1,1) xRadius:11 yRadius:11] fill];
    NSColor *ink=light>.65 ? NSColor.blackColor : NSColor.whiteColor;
    NSImage *image=[self.image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[ink]]];
    NSSize size=image.size; CGFloat scale=size.width>0 && size.height>0 ? MIN(20/size.width,20/size.height) : 0;
    [image drawInRect:NSMakeRect(NSMidX(self.bounds)-size.width*scale/2,NSMidY(self.bounds)-size.height*scale/2,size.width*scale,size.height*scale) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:self.enabled ? 1 : .45 respectFlipped:YES hints:nil];
}
@end
