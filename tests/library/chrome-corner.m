#import "Patches/SidebarLibrary/Library.h"
#import "Patches/SidebarGrain/SidebarGrain.h"
#import <stdio.h>
DPPatch DPSidebarGrain={.on=NO};
NSString *DPLibraryActiveSpace(NSWindow *window) { return nil; }
NSInteger DPGrainAmount(NSString *space) { return 0; }
NSInteger DPGrainSoftness(NSString *space) { return 0; }
NSInteger DPGrainScale(NSString *space) { return 1; }
BOOL DPGrainShown(NSString *space) { return NO; }
@implementation DPSidebarGrainView
- (void)setGrainAmount:(double)amount softness:(double)softness scale:(double)scale {}
- (void)reloadSettings {}
@end
@interface CornerBackground : NSView @end
@implementation CornerBackground
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
    [[NSColor colorWithSRGBRed:.4 green:.6 blue:.8 alpha:1] setFill]; NSRectFill(self.bounds);
    [[NSColor.labelColor colorWithAlphaComponent:.045] setFill]; NSRectFillUsingOperation(NSMakeRect(0,0,40,100),NSCompositingOperationSourceOver);
}
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,160,100) styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO;
    CornerBackground *root=[[CornerBackground alloc] initWithFrame:window.contentView.bounds]; window.contentView=root;
    NSView *panel=[[NSClassFromString(@"DPLibraryContentChrome") alloc] initWithFrame:NSMakeRect(40,0,120,100)]; [root addSubview:panel];
    for(NSString *appearance in @[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]) {
        window.appearance=[NSAppearance appearanceNamed:appearance];
        NSBitmapImageRep *pixels=[root bitmapImageRepForCachingDisplayInRect:root.bounds]; [root cacheDisplayInRect:root.bounds toBitmapImageRep:pixels];
        CGFloat scale=pixels.pixelsWide/160.0;
        NSColor *rail=[[pixels colorAtX:30*scale y:2*scale] colorUsingColorSpace:NSColorSpace.sRGBColorSpace],*corner=[[pixels colorAtX:41*scale y:2*scale] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        NSCAssert(fabs(rail.redComponent-corner.redComponent)<.02 && fabs(rail.greenComponent-corner.greenComponent)<.02,@"outside the content curve matches the rail, with no third rectangular shade");
        NSColor *inside=[[pixels colorAtX:70*scale y:30*scale] colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; NSCAssert(fabs(inside.redComponent-rail.redComponent)>.01,@"the existing panel remains distinct");
    }
    [window close]; puts("PASS: horizontal panel keeps its shade while the rounded cutout matches the navigation rail in light/dark");
} }
