#import "Patches/SidebarLibrary/MotionClock.h"
#import <QuartzCore/QuartzCore.h>
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) styleMask:0 backing:NSBackingStoreBuffered defer:YES];
    DPLibraryMotionClock *clock = [DPLibraryMotionClock new];
    __block NSUInteger frames = 0; NSMutableArray<NSNumber *> *times = [NSMutableArray new];
    clock.frame = ^{ NSCAssert(NSThread.isMainThread,@"clock delivers layout on the main thread"); frames++; [times addObject:@(CACurrentMediaTime())]; };
    [clock startForWindow:window];
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:2];
    while (frames<8 && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.03]];
    [clock stop]; NSCAssert(frames>=8,@"visible monitor clock delivers animation frames");
    NSUInteger stopped = frames; limit = [NSDate dateWithTimeIntervalSinceNow:.08];
    while (limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:limit];
    NSCAssert(frames==stopped,@"stopped clock cannot deliver queued layout callbacks");
    NSMutableArray *intervals = [NSMutableArray new]; for(NSUInteger i=1;i<times.count;i++) [intervals addObject:@((times[i].doubleValue-times[i-1].doubleValue)*1000)];
    [intervals sortUsingSelector:@selector(compare:)];
    printf("PASS: monitor clock delivers on main thread, stops queued work; median interval %.2f ms\n",[intervals[intervals.count/2] doubleValue]);
} }
