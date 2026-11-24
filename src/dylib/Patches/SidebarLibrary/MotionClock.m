#import "MotionClock.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#include <stdatomic.h>
// AppKit display links can deliver 30 Hz callbacks on a 60 Hz screen while
// native page geometry changes. Use the monitor clock for this short reveal,
// retaining AppKit's display link when a hardware clock cannot be created.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface DPLibraryMotionClock () {
    CVDisplayLinkRef _hardware;
    atomic_bool _queued;
    atomic_ulong _generation;
}
@property CADisplayLink *fallback;
@property BOOL running;
@end
@implementation DPLibraryMotionClock
- (void)enqueueFrame {
    if (atomic_exchange(&_queued,true)) return;
    unsigned long generation = atomic_load(&_generation);
    dispatch_async(dispatch_get_main_queue(),^{
        atomic_store(&self->_queued,false);
        if (self.running && generation == atomic_load(&self->_generation) && self.frame) self.frame();
    });
}
- (void)tick:(CADisplayLink *)link { if (self.running && self.frame) self.frame(); }
- (void)startForWindow:(NSWindow *)window {
    [self stop]; self.running = YES;
    CGDirectDisplayID display = [window.screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
    if (display && CVDisplayLinkCreateWithCGDisplay(display,&_hardware) == kCVReturnSuccess) {
        __weak DPLibraryMotionClock *weak = self;
        CVReturn configured = CVDisplayLinkSetOutputHandler(_hardware,^CVReturn(CVDisplayLinkRef link,const CVTimeStamp *now,const CVTimeStamp *output,CVOptionFlags flags,CVOptionFlags *outFlags) {
            [weak enqueueFrame]; return kCVReturnSuccess;
        });
        if (configured == kCVReturnSuccess && CVDisplayLinkStart(_hardware) == kCVReturnSuccess) return;
        CVDisplayLinkRelease(_hardware); _hardware = NULL;
    }
    self.fallback = [window.contentView displayLinkWithTarget:self selector:@selector(tick:)];
    CGFloat rate = MAX(30,window.screen.maximumFramesPerSecond ?: 60);
    self.fallback.preferredFrameRateRange = CAFrameRateRangeMake(MIN(60,rate),rate,rate);
    [self.fallback addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)stop {
    self.running = NO; atomic_fetch_add(&_generation,1);
    if (_hardware) { CVDisplayLinkStop(_hardware); CVDisplayLinkRelease(_hardware); _hardware = NULL; }
    [self.fallback invalidate]; self.fallback = nil;
}
- (void)dealloc { [self stop]; }
@end
#pragma clang diagnostic pop
