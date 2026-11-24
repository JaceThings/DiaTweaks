#import "Portable.h"
#import "StoreInternal.h"
@implementation DPEaselStore (PortableImport)
- (void)importPortableURL:(NSURL *)url completion:(void (^)(DPEaselDocument *,NSError *))completion {
    [self importPortableURL:url profile:@"Profile 1" completion:completion];
}
- (void)importPortableURL:(NSURL *)url profile:(NSString *)profile completion:(void (^)(DPEaselDocument *,NSError *))completion {
    if(!profile.length || ![profile.lastPathComponent isEqual:profile] || [profile hasPrefix:@"."]) { completion(nil,DPEaselError(@"Choose a normal browser profile before importing.")); return; }
    if(!url.isFileURL) { completion(nil,DPEaselError(@"Download the Easel file first, then import it.")); return; }
    [self.queue addOperationWithBlock:^{ @autoreleasepool {
        NSError *error=nil; NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        NSData *data=[attributes[NSFileType] isEqual:NSFileTypeRegular] && [attributes[NSFileSize] unsignedLongLongValue]<=128*1024*1024 ? [NSData dataWithContentsOfURL:url options:0 error:&error] : nil;
        NSDictionary *portable=data ? DPEaselReadPortable(data,&error) : nil;
        if(!portable && !error) error=DPEaselError(@"Choose an editable Easel file smaller than 128 MB.");
        NSMutableDictionary *snapshot=[portable[@"document"] mutableCopy]; NSString *identifier=NSUUID.UUID.UUIDString;
        snapshot[@"profile"]=[profile copy]; snapshot[@"id"]=identifier; snapshot[@"revision"]=@0; snapshot[@"created"]=snapshot[@"modified"]=@(NSDate.date.timeIntervalSince1970); snapshot[@"deleted"]=@NO;
        NSURL *destination=[self directory:identifier],*staging=[self.root URLByAppendingPathComponent:[@"Import-" stringByAppendingString:identifier] isDirectory:YES];
        if(!error) {
            NSURL *assetDir=[staging URLByAppendingPathComponent:@"Assets" isDirectory:YES];
            [NSFileManager.defaultManager createDirectoryAtURL:assetDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];
            for(NSString *key in portable[@"assets"]) if(!error) [portable[@"assets"][key] writeToURL:[assetDir URLByAppendingPathComponent:key] options:NSDataWritingAtomic error:&error];
            if(!error) DPEaselWriteSnapshot(snapshot,staging,&error);
            if(!error) [NSFileManager.defaultManager createDirectoryAtURL:destination.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error];
            if(!error) [NSFileManager.defaultManager moveItemAtURL:staging toURL:destination error:&error];
        }
        if(error) [NSFileManager.defaultManager removeItemAtURL:staging error:nil];
        dispatch_async(dispatch_get_main_queue(),^{
            DPEaselDocument *document=error ? nil : [[DPEaselDocument alloc] initWithSnapshot:snapshot];
            if(document) { [self.documents setObject:document forKey:identifier]; [NSNotificationCenter.defaultCenter postNotificationName:DPEaselCatalogChanged object:nil]; }
            completion(document,error);
        });
    }}];
}
@end
