#import "Scheduler.h"

static NSMutableDictionary<NSUUID *, void (^)(NSTimeInterval)> *DPIntegrationJobs;
static NSTimer *DPIntegrationTimer;

@interface DPIntegrationSubscription ()
@property(nonatomic, strong) NSUUID *identifier;
@end
@implementation DPIntegrationSubscription
- (void)cancel {
    if (!self.identifier) return;
    [DPIntegrationJobs removeObjectForKey:self.identifier];
    self.identifier = nil;
    if (!DPIntegrationJobs.count) { [DPIntegrationTimer invalidate]; DPIntegrationTimer = nil; }
}
- (void)dealloc { [self cancel]; }
@end

void DPIntegrationRunScheduledTick(NSTimeInterval now) {
    for (NSUUID *identifier in DPIntegrationJobs.allKeys.copy) {
        void (^tick)(NSTimeInterval) = DPIntegrationJobs[identifier];
        if (tick) tick(now);
    }
}

DPIntegrationSubscription *DPIntegrationSchedule(void (^tick)(NSTimeInterval)) {
    if (!tick) return nil;
    NSCAssert(NSThread.isMainThread, @"Integration scheduling belongs to the main thread");
    if (!DPIntegrationJobs) DPIntegrationJobs = [NSMutableDictionary new];
    DPIntegrationSubscription *subscription = [DPIntegrationSubscription new];
    subscription.identifier = NSUUID.UUID;
    DPIntegrationJobs[subscription.identifier] = [tick copy];
    if (!DPIntegrationTimer) {
        DPIntegrationTimer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *_) {
            DPIntegrationRunScheduledTick(NSDate.timeIntervalSinceReferenceDate);
        }];
        [NSRunLoop.mainRunLoop addTimer:DPIntegrationTimer forMode:NSRunLoopCommonModes];
    }
    return subscription;
}
