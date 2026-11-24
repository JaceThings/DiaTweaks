#import <AppKit/AppKit.h>
@interface DPEaselFrameSource : NSObject
@property NSURL *url;
@property NSUInteger index;
@property CFTimeInterval due;
@property BOOL pending;
- (BOOL)request:(NSUInteger)index completion:(void (^)(NSImage *image,NSTimeInterval delay,NSUInteger count))completion;
@end
