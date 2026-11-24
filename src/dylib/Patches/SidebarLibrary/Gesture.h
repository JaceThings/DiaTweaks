#import "Library.h"
@interface DPLibraryGesture : NSObject
@property(weak) NSWindow *window;
@property(weak) DPLibraryController *controller;
@property CGFloat x, y, start, velocity;
@property NSTimeInterval last, moved;
@property BOOL active, consumed, initiallyOpen, nativePass;
@property NSMutableArray<NSEvent *> *pending;
@property NSUInteger generation;
- (void)resetForWindow:(NSWindow *)window;
- (void)recordX:(CGFloat)x y:(CGFloat)y time:(NSTimeInterval)time;
- (BOOL)begin;
- (void)apply;
- (void)finishCancelled:(BOOL)cancelled;
@end
BOOL DPLibraryAtFirstSpace(NSWindow *window);
NSEvent *DPLibraryRouteScroll(NSEvent *event,DPLibraryGesture *gesture);
