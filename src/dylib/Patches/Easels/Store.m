#import "StoreInternal.h"
NSError *DPEaselError(NSString *message) {
    return [NSError errorWithDomain:@"DiaTweaks.Easels" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}
@implementation DPEaselStore
+ (instancetype)shared {
    static DPEaselStore *store; static dispatch_once_t once;
    dispatch_once(&once,^{ store=[[self alloc] initWithRoot:[NSURL fileURLWithPath:DPAppSupport(@"DiaPatches/Easels") isDirectory:YES]]; });
    return store;
}
- (instancetype)initWithRoot:(NSURL *)root {
    if (!root.isFileURL) return nil;
    if ((self=[super init])) {
        _root=root.URLByStandardizingPath.URLByResolvingSymlinksInPath;
        _documents=NSMapTable.strongToWeakObjectsMapTable; _lifecycle=NSMutableDictionary.new; _queue=NSOperationQueue.new;
        _imageInfo=NSCache.new; _imageInfo.countLimit=128;
        _queue.maxConcurrentOperationCount=1; _queue.qualityOfService=NSQualityOfServiceUtility;
    }
    return self;
}
- (NSURL *)directory:(NSString *)identifier {
    if (!DPEaselUUID(identifier)) return nil;
    return [[self.root URLByAppendingPathComponent:@"Documents" isDirectory:YES] URLByAppendingPathComponent:identifier.uppercaseString isDirectory:YES];
}
- (NSURL *)pageURL:(NSString *)identifier { return [[self directory:identifier] URLByAppendingPathComponent:@"index.html"]; }
- (NSString *)identifierForURL:(NSURL *)url {
    if (!url.isFileURL || url.query.length || url.fragment.length || url.host.length) return nil;
    NSString *identifier=url.URLByDeletingLastPathComponent.lastPathComponent;
    NSURL *expected=[self pageURL:identifier];
    return expected && [url.URLByStandardizingPath.URLByResolvingSymlinksInPath.path isEqual:expected.path] ? identifier.uppercaseString : nil;
}
- (DPEaselDocument *)cachedDocumentForURL:(NSURL *)url {
    NSString *identifier=[self identifierForURL:url];
    return identifier ? [self.documents objectForKey:identifier] : nil;
}
- (void)save:(DPEaselDocument *)document completion:(void (^)(NSError *))completion {
    NSAssert(NSThread.isMainThread,@"Capture immutable snapshots on main");
    if (!document || document.deleted) { if(completion) completion(DPEaselError(@"The Easel is deleted")); return; }
    BOOL previouslySaved=[self.documents objectForKey:document.identifier]!=nil;
    [self.documents setObject:document forKey:document.identifier];
    NSDictionary *snapshot=document.snapshot; NSURL *directory=[self directory:document.identifier];
    [self.queue addOperationWithBlock:^{
        NSError *error=nil;
        if(previouslySaved && ![NSFileManager.defaultManager fileExistsAtPath:[directory URLByAppendingPathComponent:@"document.json"].path])
            error=DPEaselError(@"The saved Easel is unavailable. Its recovery files have been preserved.");
        else DPEaselWriteSnapshot(snapshot,directory,&error);
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            if(!error) [NSNotificationCenter.defaultCenter postNotificationName:DPEaselCatalogChanged object:self];
            if(completion) completion(error);
        }];
    }];
}
- (void)flush { [self.queue waitUntilAllOperationsAreFinished]; }
@end
