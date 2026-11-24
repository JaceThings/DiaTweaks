#import "Library.h"
#import "MotionClock.h"
typedef struct { float x,y,r,g,b,a,seed; } DPLibraryParticle;
NSData *DPLibraryDustSamples(CGImageRef image,NSSize size,NSUInteger budget,CGFloat *step);
@interface DPLibraryDust : NSView
@property NSImage *image;
@property NSRect imageRect;
@property NSData *samples;
@property CGFloat step;
@property CFTimeInterval started;
@property DPLibraryMotionClock *clock;
- (void)start;
- (void)stop;
@end
