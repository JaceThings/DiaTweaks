#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.controlAccentColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static void waitFor(BOOL (^done)(void)) {
    NSDate *until=[NSDate dateWithTimeIntervalSinceNow:3];
    while(!done() && until.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(done(),@"image operation completes");
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(200,300)];
    [DPEaselStore.shared save:document completion:nil]; [DPEaselStore.shared flush];
    NSURL *source=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    NSBitmapImageRep *pixels=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:16 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    for(NSUInteger y=0;y<16;y++) for(NSUInteger x=0;x<16;x++) {
        unsigned char *pixel=pixels.bitmapData+y*pixels.bytesPerRow+x*4;
        pixel[0]=255; pixel[1]=0; pixel[2]=0; pixel[3]=255;
    }
    [[pixels representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToURL:source atomically:YES];
    __block NSString *asset=nil;
    [DPEaselStore.shared importImage:source document:document completion:^(NSString *value,NSSize size,NSError *error){ asset=value; }];
    waitFor(^BOOL{ return asset!=nil; });
    NSURL *url=[DPEaselStore.shared assetURL:asset document:document.identifier]; __block BOOL warm=NO;
    [DPEaselImageCache.shared thumbnail:url completion:^(NSImage *image){ warm=image!=nil; }]; waitFor(^BOOL{ return warm; });
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,200,300)]; canvas.document=document;
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,200,300) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO; window.contentView=canvas;
    [document replaceObjects:@[@{@"id":NSUUID.UUID.UUIDString,@"type":@"image",@"asset":asset,@"rect":@[@20,@20,@60,@60],@"order":@1,@"z":@1}] action:@"Fixture"];
    for(NSUInteger pass=0;pass<2;pass++) {
        [canvas.images removeAllObjects];
        NSBitmapImageRep *render=[canvas bitmapImageRepForCachingDisplayInRect:canvas.bounds]; [canvas cacheDisplayInRect:canvas.bounds toBitmapImageRep:render];
        NSUInteger red=0;
        for(NSInteger y=0;y<render.pixelsHigh;y+=4) for(NSInteger x=0;x<render.pixelsWide;x+=4) {
            NSColor *color=[[render colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            if(color.redComponent>.8 && color.greenComponent<.2 && color.blueComponent<.2) red++;
        }
        NSCAssert(red>100,@"the first redraw after local-cache eviction must paint the cached image, not leave a placeholder until the next click");
    }
    [canvas removeFromSuperview]; [window close];
    [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtURL:source error:nil]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: first-paint image pixels after repeated per-canvas cache eviction; no second draw or click required");
} }
