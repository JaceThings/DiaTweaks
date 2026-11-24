#import <Foundation/Foundation.h>
#import <math.h>
// Recovery starts at deletion, never at creation or last edit. Legacy trash gets a full grace period.
static const NSTimeInterval DPLocalRecoveryPeriod=30.0*24*60*60;
static inline BOOL DPLocalDeletionExpired(id stamp,NSTimeInterval now) {
    if(![stamp isKindOfClass:NSNumber.class]) return NO;
    double value=[stamp doubleValue]; return isfinite(value) && value>0 && now-value>=DPLocalRecoveryPeriod;
}
static inline BOOL DPLocalRealDirectory(NSURL *url) {
    NSNumber *link=nil,*directory=nil;
    return [url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil] && !link.boolValue &&
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil] && directory.boolValue;
}
static inline NSURL *DPLocalDeletionMarker(NSURL *directory) { return [directory URLByAppendingPathComponent:@"deleted.json"]; }
static inline BOOL DPLocalRecordDeletion(NSURL *directory,NSTimeInterval now,NSError **error) {
    if(!DPLocalRealDirectory(directory)) return NO;
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"schema":@1,@"deletedAt":@(now)} options:0 error:error];
    return data && [data writeToURL:DPLocalDeletionMarker(directory) options:NSDataWritingAtomic error:error];
}
static inline NSNumber *DPLocalDeletionTime(NSURL *directory) {
    NSURL *url=DPLocalDeletionMarker(directory); NSNumber *link=nil,*size=nil;
    [url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil]; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if(link.boolValue || !size || size.unsignedLongLongValue>1024) return nil;
    NSData *data=[NSData dataWithContentsOfURL:url]; id value=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if(![value isKindOfClass:NSDictionary.class] || ![value[@"schema"] isEqual:@1]) return nil;
    id stamp=value[@"deletedAt"]; double time=[stamp respondsToSelector:@selector(doubleValue)] ? [stamp doubleValue] : 0;
    return [stamp isKindOfClass:NSNumber.class] && isfinite(time) && time>0 ? stamp : nil;
}
// Call only on the store's serial I/O queue. Never follows links or removes unknown files.
static inline void DPLocalMaintainTrash(NSURL *trash,NSTimeInterval now) {
    if(!DPLocalRealDirectory(trash)) return;
    NSFileManager *files=NSFileManager.defaultManager;
    NSArray *children=[files contentsOfDirectoryAtURL:trash includingPropertiesForKeys:@[NSURLIsSymbolicLinkKey,NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for(NSURL *child in children) {
        if(![[NSUUID alloc] initWithUUIDString:child.lastPathComponent] || !DPLocalRealDirectory(child)) continue;
        NSNumber *stamp=DPLocalDeletionTime(child);
        if(!stamp) { DPLocalRecordDeletion(child,now,nil); continue; }
        if(DPLocalDeletionExpired(stamp,now)) [files removeItemAtURL:child error:nil];
    }
}
