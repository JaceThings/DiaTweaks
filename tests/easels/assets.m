#import "Patches/Easels/Assets.h"
#import <stdio.h>
NSString *DPAppSupport(NSString *path) { abort(); }
static void waitUntil(BOOL (^done)(void)) {
    NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:10];
    while(!done() && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(done(),@"background image work completes");
}
int main(void) { @autoreleasepool {
    NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *source=[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"source.png"]];
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2000 pixelsHigh:1000 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    memset(bitmap.bitmapData,0,bitmap.bytesPerRow*1000); bitmap.bitmapData[3]=128;
    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToURL:source atomically:YES];
    DPEaselStore *store=[[DPEaselStore alloc] initWithRoot:[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"store"]]];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)];
    __block NSString *asset=nil; __block BOOL finished=NO;
    [store importImage:source document:document completion:^(NSString *value,NSSize size,NSError *error) {
        NSCAssert(NSThread.isMainThread && !error && size.width==2000 && size.height==1000,@"valid import validates metadata off-main and returns on main");
        asset=value; finished=YES;
    }];
    waitUntil(^BOOL { return finished; });
    NSURL *owned=[store assetURL:asset document:document.identifier];
    [NSFileManager.defaultManager removeItemAtURL:source error:nil];
    NSCAssert([NSFileManager.defaultManager fileExistsAtPath:owned.path],@"owned bytes survive removal of original Downloads file");
    NSCAssert(![store assetURL:@"../../escape" document:document.identifier],@"assets cannot traverse out of document");
    __block NSUInteger completed=0;
    for(NSUInteger i=0;i<80;i++) [DPEaselImageCache.shared thumbnail:owned completion:^(NSImage *image) {
        NSCAssert(image && NSThread.isMainThread && image.size.width<=1024 && image.size.height<=1024,@"decode is bounded and every coalesced subscriber completes"); completed++;
    }];
    waitUntil(^BOOL { return completed==80; });
    NSURL *bad=[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"not-an-image.png"]];
    [@"not image bytes" writeToURL:bad atomically:YES encoding:NSUTF8StringEncoding error:nil];
    finished=NO;
    [store importImage:bad document:document completion:^(NSString *value,NSSize size,NSError *error) { NSCAssert(!value && error,@"extension alone cannot admit arbitrary files"); finished=YES; }];
    waitUntil(^BOOL { return finished; });
    [DPEaselImageCache.shared clear]; [store flush];
    [NSFileManager.defaultManager removeItemAtPath:folder error:nil];
    puts("PASS: private asset copy, original removal, actual image validation, bounded decoding, main-thread completion and 80 coalesced requests");
} }
