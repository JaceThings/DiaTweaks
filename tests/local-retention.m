#import "Patches/SidebarLibrary/Retention.h"
#import "Patches/Tasks/StoreInternal.h"
#import <stdio.h>
NSString *DPAppSupport(NSString *path) { return @"/tmp/unused-retention-store"; }
static void waitFor(BOOL (^ready)(void)) {
    NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];
    while(!ready() && end.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    NSCAssert(ready(),@"store loads");
}
int main(void) { @autoreleasepool {
    double now=NSDate.date.timeIntervalSince1970; NSFileManager *files=NSFileManager.defaultManager;
    NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    NSURL *trash=[root URLByAppendingPathComponent:@"Trash" isDirectory:YES];
    NSMutableArray *folders=NSMutableArray.new;
    for(NSUInteger i=0;i<4;i++) {
        NSURL *folder=[trash URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        [files createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil]; [folders addObject:folder];
    }
    NSCAssert(DPLocalRecordDeletion(folders[0],now-DPLocalRecoveryPeriod,nil),@"record old deletion");
    DPLocalRecordDeletion(folders[1],now-DPLocalRecoveryPeriod+1,nil); DPLocalRecordDeletion(folders[3],now+100,nil);
    NSURL *outside=[root URLByAppendingPathComponent:@"outside" isDirectory:YES]; [files createDirectoryAtURL:outside withIntermediateDirectories:YES attributes:nil error:nil];
    DPLocalRecordDeletion(outside,now-DPLocalRecoveryPeriod-1,nil);
    NSURL *link=[trash URLByAppendingPathComponent:NSUUID.UUID.UUIDString]; [files createSymbolicLinkAtURL:link withDestinationURL:outside error:nil];
    DPLocalMaintainTrash(trash,now);
    NSCAssert(![files fileExistsAtPath:[folders[0] path]] && [files fileExistsAtPath:[folders[1] path]],@"only expired deletions are removed at 30 days");
    NSCAssert([DPLocalDeletionTime(folders[2]) doubleValue]==now && [files fileExistsAtPath:outside.path],@"legacy trash receives a full grace period; linked folders are never followed");
    NSCAssert([files fileExistsAtPath:[folders[3] path]],@"future timestamp is retained rather than deleted after clock changes");
    NSDictionary *task=@{@"id":NSUUID.UUID.UUIDString,@"text":@"Recovery",@"completed":@YES,@"created":@(now-10000000)};
    NSArray *old=DPTasksDeleted(@[task],now-DPLocalRecoveryPeriod-1), *recent=DPTasksDeleted(@[task],now-10);
    NSMutableDictionary *different=[recent.firstObject mutableCopy]; different[@"id"]=NSUUID.UUID.UUIDString;
    NSMutableDictionary *legacy=[task mutableCopy]; legacy[@"id"]=NSUUID.UUID.UUIDString;
    NSURL *taskRoot=[root URLByAppendingPathComponent:@"Tasks" isDirectory:YES]; [files createDirectoryAtURL:taskRoot withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"schema":@1,@"items":@[],@"cleared":@[old.firstObject,different,legacy]} options:0 error:nil];
    [data writeToURL:[taskRoot URLByAppendingPathComponent:@"tasks.json"] atomically:YES];
    DPTaskStore *store=[[DPTaskStore alloc] initWithRoot:taskRoot]; waitFor(^BOOL{ return store.loaded; }); [store flush];
    NSCAssert(store.cleared.count==2 && [store.cleared.lastObject[@"deletedAt"] doubleValue]>=now,@"tasks expire by deletion time; legacy tasks migrate without losing them");
    [store restoreCleared]; [store flush]; NSCAssert(store.items.count==2 && !store.items.firstObject[@"deletedAt"],@"restore clears the expiry so later deletion gets another 30 days");
    [store clear]; [store flush]; NSCAssert(store.cleared.count==2 && [store.cleared.firstObject[@"deletedAt"] doubleValue]>=now,@"new deletion resets recovery window");
    [files removeItemAtURL:root error:nil]; puts("PASS: 30-day expiry, legacy grace periods, restore/reset, future clocks and symlink isolation");
} }
