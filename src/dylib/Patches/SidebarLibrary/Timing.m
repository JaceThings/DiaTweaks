#import "Library.h"
#ifdef DPLIBRARY_DIAGNOSTICS
@interface DPLibraryTiming : NSObject
@property CFTimeInterval previous;
@property NSMutableArray<NSNumber *> *intervals, *costs;
@end
@implementation DPLibraryTiming @end
static double DPLibraryPercentile(NSArray<NSNumber *> *values,double fraction) {
    NSArray *sorted = [values sortedArrayUsingSelector:@selector(compare:)];
    return sorted.count ? [sorted[MIN(sorted.count-1,(NSUInteger)floor((sorted.count-1)*fraction))] doubleValue] : 0;
}
void DPLibraryRecordMotion(id motion,CFTimeInterval began,BOOL opening,BOOL complete) {
    static NSMapTable *timings; if (!timings) timings = [NSMapTable weakToStrongObjectsMapTable];
    DPLibraryTiming *timing = [timings objectForKey:motion];
    if (!timing) { timing = [DPLibraryTiming new]; timing.intervals = [NSMutableArray new]; timing.costs = [NSMutableArray new]; [timings setObject:timing forKey:motion]; }
    if (timing.previous) [timing.intervals addObject:@((began-timing.previous)*1000)]; timing.previous = began;
    [timing.costs addObject:@((CACurrentMediaTime()-began)*1000)];
    if (!complete) return;
    NSString *path = @"/tmp/sidebar-library-motion-timing.json";
    NSMutableArray *history = [[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] ?: [@"[]" dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil] mutableCopy] ?: [NSMutableArray new];
    DPLibraryController *owner = [motion valueForKey:@"owner"];
    [history addObject:@{@"appActive":@(NSApp.isActive),@"windowKey":@(owner.window.isKeyWindow),@"screenMaxFPS":@(owner.window.screen.maximumFramesPerSecond),@"pid":@(NSProcessInfo.processInfo.processIdentifier),@"direction":opening ? @"open" : @"close",@"frames":@(timing.costs.count),@"intervalP50ms":@(DPLibraryPercentile(timing.intervals,.5)),@"intervalP95ms":@(DPLibraryPercentile(timing.intervals,.95)),@"layoutP95ms":@(DPLibraryPercentile(timing.costs,.95)),@"layoutMaxMs":@(DPLibraryPercentile(timing.costs,1))}];
    while (history.count>80) [history removeObjectAtIndex:0];
    [[NSJSONSerialization dataWithJSONObject:history options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
    [timings removeObjectForKey:motion];
}
#endif
