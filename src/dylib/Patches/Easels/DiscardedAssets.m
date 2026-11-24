#import "Assets.h"
#import "StoreInternal.h"
@implementation DPEaselStore (Discarding)
- (void)discardUnplacedAsset:(NSString *)asset document:(DPEaselDocument *)document {
    NSAssert(NSThread.isMainThread,@"Unplaced import ownership is checked on main");
    if(!DPEaselUUID(asset) || !document) return;
    for(NSDictionary *object in document.objects) if([object[@"asset"] isEqual:asset]) return;
    NSString *identifier=document.identifier;
    [self.imageInfo removeObjectForKey:[self assetURL:asset document:identifier].path];
    [self.queue addOperationWithBlock:^{
        // Resolve after earlier queued trash/restore operations, so an abandoned
        // newly imported asset cannot be left behind merely by a tab deletion.
        NSURL *url=[self readableAssetURL:asset document:identifier];
        if([url.URLByResolvingSymlinksInPath.path isEqual:url.path]) [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }];
}
@end
