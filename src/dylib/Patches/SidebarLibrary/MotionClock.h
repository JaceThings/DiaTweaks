#import <AppKit/AppKit.h>
@interface DPLibraryMotionClock : NSObject
@property(copy) dispatch_block_t frame;
- (void)startForWindow:(NSWindow *)window;
- (void)stop;
@end
