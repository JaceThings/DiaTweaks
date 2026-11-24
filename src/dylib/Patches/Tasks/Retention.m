#import "StoreInternal.h"
#import "../SidebarLibrary/Retention.h"
NSArray *DPTasksDeleted(NSArray *items,NSTimeInterval now) {
    NSMutableArray *result=NSMutableArray.new;
    for(NSDictionary *item in items) { NSMutableDictionary *copy=[item mutableCopy]; copy[@"deletedAt"]=@(now); [result addObject:copy]; }
    return result;
}
NSArray *DPTasksRestored(NSArray *items) {
    NSMutableArray *result=NSMutableArray.new;
    for(NSDictionary *item in items) { NSMutableDictionary *copy=[item mutableCopy]; [copy removeObjectForKey:@"deletedAt"]; [result addObject:copy]; }
    return result;
}
@implementation DPTaskStore (Retention)
- (void)maintainRecovery {
    if(!self.loaded || self.error || !self.cleared.count) return;
    NSTimeInterval now=NSDate.date.timeIntervalSince1970; NSMutableArray *kept=NSMutableArray.new; BOOL changed=NO;
    for(NSDictionary *item in self.cleared) {
        if(DPLocalDeletionExpired(item[@"deletedAt"],now)) { changed=YES; continue; }
        NSNumber *stamp=item[@"deletedAt"];
        if(![stamp isKindOfClass:NSNumber.class] || !isfinite(stamp.doubleValue) || stamp.doubleValue<=0) {
            [kept addObject:DPTasksDeleted(@[item],now).firstObject]; changed=YES;
        } else [kept addObject:item];
    }
    if(changed) { self.cleared=kept; [self save]; }
}
@end
