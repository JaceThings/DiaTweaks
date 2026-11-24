#import "StoreInternal.h"
NSNotificationName const DPTasksChanged=@"DPTasksChanged";
BOOL DPTasksValidSnapshot(id snapshot) {
    if(![snapshot isKindOfClass:NSDictionary.class] || ![snapshot[@"schema"] isEqual:@1]) return NO;
    NSMutableSet *ids=NSMutableSet.new;
    for(NSString *key in @[@"items",@"cleared"]) {
        id entries=snapshot[key]; if(![entries isKindOfClass:NSArray.class] || [entries count]>50000) return NO;
        for(id entry in entries) {
            if(![entry isKindOfClass:NSDictionary.class]) return NO;
            NSString *identifier=entry[@"id"],*text=entry[@"text"];
            if(![identifier isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:identifier] || [ids containsObject:identifier]) return NO;
            if(![text isKindOfClass:NSString.class] || !text.length || text.length>4096) return NO;
            if(![entry[@"completed"] isKindOfClass:NSNumber.class] || ![entry[@"created"] isKindOfClass:NSNumber.class]) return NO;
            [ids addObject:identifier];
        }
    }
    return YES;
}
@implementation DPTaskStore
static NSMutableDictionary<NSString *,DPTaskStore *> *DPProfileStores;
+ (instancetype)shared { return [self storeForProfile:@"Profile 1"]; }
+ (instancetype)storeForProfile:(NSString *)profile {
    NSAssert(NSThread.isMainThread,@"Profile stores resolve on main");
    if(!profile.length || ![profile.lastPathComponent isEqual:profile] || [profile hasPrefix:@"."]) return nil;
    if(!DPProfileStores) DPProfileStores=NSMutableDictionary.new;
    DPTaskStore *store=DPProfileStores[profile];
    if(!store) {
        // Legacy shared tasks belong to the original profile; keep their existing file in place.
        NSString *path=[profile isEqual:@"Profile 1"] ? @"DiaPatches/Tasks" : [@"DiaPatches/Tasks/Profiles" stringByAppendingPathComponent:profile];
        store=[[self alloc] initWithRoot:[NSURL fileURLWithPath:DPAppSupport(path) isDirectory:YES]];
        DPProfileStores[profile]=store;
    }
    [store maintainRecovery];
    return store;
}
+ (void)flushAll { for(DPTaskStore *store in DPProfileStores.allValues) [store flush]; }
- (instancetype)initWithRoot:(NSURL *)root {
    if(!root.isFileURL) return nil;
    if((self=[super init])) {
        _root=root; _items=@[]; _cleared=@[]; _queue=NSOperationQueue.new;
        _queue.maxConcurrentOperationCount=1; _queue.qualityOfService=NSQualityOfServiceUtility;
        __weak DPTaskStore *weak=self;
        [_queue addOperationWithBlock:^{
            NSURL *url=[root URLByAppendingPathComponent:@"tasks.json"]; NSError *error=nil;
            NSDictionary *snapshot=nil;
            if([NSFileManager.defaultManager fileExistsAtPath:url.path]) {
                NSNumber *size=nil; [url getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
                NSData *data=size.unsignedLongLongValue<=32*1024*1024 ? [NSData dataWithContentsOfURL:url options:0 error:&error] : nil;
                snapshot=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
                if(!DPTasksValidSnapshot(snapshot)) error=[NSError errorWithDomain:@"DiaTweaks.Tasks" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Saved tasks could not be read. The original file has been preserved."}];
            }
            dispatch_async(dispatch_get_main_queue(),^{
                DPTaskStore *store=weak; if(!store) return;
                store.items=error ? @[] : snapshot[@"items"] ?: @[]; store.cleared=error ? @[] : snapshot[@"cleared"] ?: @[];
                store.error=error; store.loaded=YES; [store maintainRecovery]; [store publish];
            });
        }];
    } return self;
}
- (void)publish { [NSNotificationCenter.defaultCenter postNotificationName:DPTasksChanged object:self]; }
- (BOOL)add:(NSString *)text {
    NSAssert(NSThread.isMainThread,@"Tasks mutate on main");
    text=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!self.loaded || self.error || !text.length || text.length>4096 || self.items.count>=50000) return NO;
    NSDictionary *item=@{@"id":NSUUID.UUID.UUIDString,@"text":text,@"completed":@NO,@"created":@(NSDate.date.timeIntervalSince1970)};
    self.items=[@[item] arrayByAddingObjectsFromArray:self.items]; [self save]; return YES;
}
- (void)setCompleted:(BOOL)completed identifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread,@"Tasks mutate on main");
    if(!self.loaded || self.error) return;
    NSMutableArray *items=[self.items mutableCopy];
    NSUInteger index=[items indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger index,BOOL *stop){ return [item[@"id"] isEqual:identifier]; }];
    if(index==NSNotFound || [items[index][@"completed"] boolValue]==completed) return;
    NSMutableDictionary *item=[items[index] mutableCopy]; item[@"completed"]=@(completed); items[index]=item; self.items=items; [self save];
}
- (void)clear {
    if(!self.loaded || self.error || !self.items.count || self.items.count+self.cleared.count>50000) return;
    self.cleared=[DPTasksDeleted(self.items,NSDate.date.timeIntervalSince1970) arrayByAddingObjectsFromArray:self.cleared]; self.items=@[]; [self save];
}
- (void)restoreCleared {
    if(!self.loaded || self.error || !self.cleared.count || self.items.count+self.cleared.count>50000) return;
    self.items=[DPTasksRestored(self.cleared) arrayByAddingObjectsFromArray:self.items]; self.cleared=@[]; [self save];
}
- (void)save {
    NSDictionary *snapshot=@{@"schema":@1,@"items":self.items,@"cleared":self.cleared};
    NSURL *root=self.root; __weak DPTaskStore *weak=self;
    [self.queue addOperationWithBlock:^{
        NSError *error=nil;
        [NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:&error];
        NSData *data=error ? nil : [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:&error];
        if(data) [data writeToURL:[root URLByAppendingPathComponent:@"tasks.json"] options:NSDataWritingAtomic error:&error];
        if(error) dispatch_async(dispatch_get_main_queue(),^{ weak.error=error; [weak publish]; });
    }];
    [self publish];
}
- (void)flush { [self.queue waitUntilAllOperationsAreFinished]; }
@end
