#import "Patches/SidebarLibrary/Library.h"
#import <AVFoundation/AVFoundation.h>
NSImage *DPLibraryVideoStill(NSURL *url);
int main(int argc,const char **argv) { @autoreleasepool {
 NSImage *remote = DPLibraryVideoStill([NSURL URLWithString:@"https://example.com/movie.mp4"]);
 NSCAssert(!remote,@"thumbnail generation never fetches remote video");
 NSImage *missing = DPLibraryVideoStill([NSURL fileURLWithPath:@"/tmp/library-nonexistent.mp4"]);
 NSCAssert(!missing,@"missing video fails safely");
 if (argc > 1) {
  NSImage *still = DPLibraryVideoStill([NSURL fileURLWithPath:@(argv[1])]);
  NSCAssert(still && still.size.width <= 420 && still.size.height <= 420,@"bounded real video still");
 }
 NSLog(@"PASS: remote URL excluded and missing video fails safely");
} }
