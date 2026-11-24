#import "Patches/SidebarLibrary/Library.h"
BOOL DPLibraryIsMovieURL(NSURL *url) { return NO; }
NSImage *DPLibraryVideoStill(NSURL *url) { return nil; }
int main(void) { @autoreleasepool {
    NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:2 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    memset(bitmap.bitmapData,255,bitmap.bytesPerRow*2);
    NSData *data=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    __block NSUInteger completed=0,images=0;
    for(NSUInteger index=0;index<140;index++) {
        NSString *path=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu.png",index<100 ? 0UL : index]];
        [data writeToFile:path atomically:YES];
        DPLibraryThumbnail([NSURL fileURLWithPath:path],^(NSImage *image){ completed++; if(image) images++; });
    }
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:10];
    while(completed<140 && deadline.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    [NSFileManager.defaultManager removeItemAtPath:folder error:nil];
    NSCAssert(completed==140 && images==140,@"all coalesced and saturated thumbnail callers receive images");
    puts("PASS: 140 thumbnail callers complete with images; no coalescing or queue saturation drops");
} }
