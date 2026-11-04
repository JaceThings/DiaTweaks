#import <Foundation/Foundation.h>

// One main-run-loop timer for transport and all preview subscriptions.
@interface DPIntegrationSubscription : NSObject
- (void)cancel;
@end
DPIntegrationSubscription *DPIntegrationSchedule(void (^tick)(NSTimeInterval now));
void DPIntegrationRunScheduledTick(NSTimeInterval now);
