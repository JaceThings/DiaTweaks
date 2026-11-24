#import "StoreInternal.h"
#import "../SidebarLibrary/Retention.h"
@implementation DPEaselStore (Listing)
- (void)list:(void (^)(NSArray<NSDictionary *> *,NSError *))completion {
    [self listFolder:@"Documents" completion:completion];
}
- (void)listTrashed:(void (^)(NSArray<NSDictionary *> *,NSError *))completion {
    [self listFolder:@"Trash" completion:completion];
}
- (void)listFolder:(NSString *)folder completion:(void (^)(NSArray<NSDictionary *> *,NSError *))completion {
    [self.queue addOperationWithBlock:^{ @autoreleasepool {
        DPLocalMaintainTrash([self.root URLByAppendingPathComponent:@"Trash" isDirectory:YES],NSDate.date.timeIntervalSince1970);
        NSURL *directory=[self.root URLByAppendingPathComponent:folder isDirectory:YES];
        NSError *error=nil;
        NSArray *entries=[NSFileManager.defaultManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:@[NSURLIsSymbolicLinkKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if(error.code==NSFileReadNoSuchFileError) error=nil;
        NSMutableArray *records=NSMutableArray.new;
        for(NSURL *entry in entries) {
            NSNumber *link=nil; [entry getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
            if(!DPEaselUUID(entry.lastPathComponent) || link.boolValue) continue;
            NSURL *summary=[entry URLByAppendingPathComponent:@"summary.json"];
            NSNumber *size=nil; [summary getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
            if(!size || size.unsignedLongLongValue>65536) continue;
            NSData *data=[NSData dataWithContentsOfURL:summary options:0 error:nil];
            NSDictionary *record=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if(![record isKindOfClass:NSDictionary.class] || ![record[@"id"] isEqual:entry.lastPathComponent] ||
                ![record[@"title"] isKindOfClass:NSString.class] || ![record[@"modified"] isKindOfClass:NSNumber.class]) continue;
            [records addObject:record];
        }
        [records sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
            NSComparisonResult result=[b[@"modified"] compare:a[@"modified"]];
            return result==NSOrderedSame ? [a[@"id"] compare:b[@"id"]] : result;
        }];
        [NSOperationQueue.mainQueue addOperationWithBlock:^{ completion(records,error); }];
    }}];
}
@end
