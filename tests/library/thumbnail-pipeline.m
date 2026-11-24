#import "Patches/SidebarLibrary/Library.h"
int main(int argc,const char **argv) { @autoreleasepool {
    NSCAssert(argc == 2,@"provide a large image fixture");
    NSString *dotless = @"/tmp/library-thumbnail-dotless";
    [@"not an image" writeToFile:dotless atomically:YES encoding:NSUTF8StringEncoding error:nil];
    DPLibraryFile *file = [DPLibraryFile new];
    NSCAssert(!DPLibraryIsMedia(file),@"nil extension cannot throw");
    file.path = dotless; NSCAssert(!DPLibraryIsMedia(file),@"extensionless classification is safe");
    file.path = @"/tmp/ends-in-period."; NSCAssert(!DPLibraryIsMedia(file),@"empty filename tag is safe");
    __block NSUInteger completed = 0;
    DPLibraryThumbnail([NSURL fileURLWithPath:dotless],^(NSImage *image) { NSCAssert(!image,@"invalid image has no thumbnail"); completed++; });
    DPLibraryThumbnail([NSURL fileURLWithPath:@"/tmp/library-thumbnail-missing.png"],^(NSImage *image) { NSCAssert(!image,@"missing file fails safely"); completed++; });
    DPLibraryThumbnail([NSURL fileURLWithPath:@(argv[1])],^(NSImage *image) {
        NSCAssert(image && image.size.width <= 420 && image.size.height <= 420,@"real image is bounded to 420 pixels"); completed++;
    });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (completed < 3 && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    NSCAssert(completed == 3,@"every request completes on the main queue");
    NSLog(@"PASS: nil/empty filename tags, invalid/missing files, main-queue completion and bounded image decoding");
} }
