#import "StoreInternal.h"
@implementation DPEaselStore (Loading)
- (DPEaselDocument *)load:(NSString *)identifier error:(NSError **)error {
    return [self loadIdentifier:identifier trashed:NO error:error];
}
- (DPEaselDocument *)loadTrashed:(NSString *)identifier error:(NSError **)error {
    return [self loadIdentifier:identifier trashed:YES error:error];
}
- (DPEaselDocument *)loadIdentifier:(NSString *)identifier trashed:(BOOL)trashed error:(NSError **)error {
    NSAssert(NSThread.isMainThread,@"The document registry belongs to the main thread");
    NSURL *directory=[self directory:identifier];
    if(trashed && directory) directory=[[self.root URLByAppendingPathComponent:@"Trash" isDirectory:YES] URLByAppendingPathComponent:identifier];
    if(!directory || ![directory.path isEqual:directory.URLByResolvingSymlinksInPath.path]) {
        if(error) *error=DPEaselError(@"Invalid Easel identifier or storage location"); return nil;
    }
    identifier=identifier.uppercaseString;
    DPEaselDocument *cached=[self.documents objectForKey:identifier];
    if(cached && cached.deleted==trashed) return cached;
    if(cached) { if(error) *error=DPEaselError(@"This Easel has moved. Refresh its Library view."); return nil; }
    for(NSString *name in @[@"document.json",@"recovery.json"]) {
        NSURL *url=[directory URLByAppendingPathComponent:name];
        NSNumber *bytes=nil; [url getResourceValue:&bytes forKey:NSURLFileSizeKey error:nil];
        if(!bytes || bytes.unsignedLongLongValue>16*1024*1024) continue;
        NSData *data=[NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
        NSDictionary *snapshot=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if(![snapshot isKindOfClass:NSDictionary.class] || ![snapshot[@"id"] isEqual:identifier]) continue;
        DPEaselDocument *document=[[DPEaselDocument alloc] initWithSnapshot:snapshot];
        if(document) {
            if(trashed) [document setDeleted:YES];
            [self.documents setObject:document forKey:identifier];
            if(!trashed && ![snapshot[@"titleModel"] isEqual:@2]) [self save:document completion:nil];
            return document;
        }
    }
    if(error) *error=DPEaselError(@"This Easel could not be opened. Its files have been preserved.");
    return nil;
}
@end
