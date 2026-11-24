#import "Assets.h"
#import "StoreInternal.h"
#import "ImageIO.h"
@implementation DPEaselStore (Assets)
- (NSDictionary *)imageInfoForAsset:(NSString *)asset document:(NSString *)identifier { return [self.imageInfo objectForKey:[self assetURL:asset document:identifier].path]; }
- (NSURL *)assetURL:(NSString *)asset document:(NSString *)identifier {
    if(!DPEaselUUID(asset)) return nil;
    return [[[self directory:identifier] URLByAppendingPathComponent:@"Assets" isDirectory:YES] URLByAppendingPathComponent:asset];
}
- (NSURL *)readableAssetURL:(NSString *)asset document:(NSString *)identifier {
    NSURL *url=[self assetURL:asset document:identifier];
    if(!url || [NSFileManager.defaultManager fileExistsAtPath:url.path]) return url;
    return [[[[self.root URLByAppendingPathComponent:@"Trash" isDirectory:YES] URLByAppendingPathComponent:identifier isDirectory:YES] URLByAppendingPathComponent:@"Assets" isDirectory:YES] URLByAppendingPathComponent:asset];
}
- (void)importImage:(NSURL *)url document:(DPEaselDocument *)document completion:(void (^)(NSString *,NSSize,NSError *))completion {
    NSAssert(NSThread.isMainThread,@"Imports enter through the document's main-thread registry");
    if(!url.isFileURL || !document || document.deleted) { completion(nil,NSZeroSize,DPEaselError(@"Choose a local image for an existing Easel.")); return; }
    NSString *asset=NSUUID.UUID.UUIDString;
    NSURL *destination=[self assetURL:asset document:document.identifier];
    [self.queue addOperationWithBlock:^{ @autoreleasepool {
        NSError *error=nil; NSSize size=NSZeroSize; NSUInteger frameCount=1;
        NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        if(!error && (![attributes[NSFileType] isEqual:NSFileTypeRegular] || [attributes[NSFileSize] unsignedLongLongValue]>100*1024*1024))
            error=DPEaselError(@"Choose an image smaller than 100 MB.");
        DPEaselImageFunctions api=DPEaselImageIO();
        CGImageSourceRef source=!error && api.open ? api.open((__bridge CFURLRef)url,(__bridge CFDictionaryRef)@{@"kCGImageSourceShouldCache":@NO}) : nil;
        NSString *type=source && api.type ? (__bridge NSString *)api.type(source) : nil;
        if(!error && ![@[@"public.png",@"public.jpeg",@"com.compuserve.gif"] containsObject:type ?: @""])
            error=DPEaselError(@"This image is not a supported PNG, JPEG or GIF.");
        if(!error && api.properties) {
            NSDictionary *properties=CFBridgingRelease(api.properties(source,0,NULL));
            size=NSMakeSize([properties[@"PixelWidth"] doubleValue],[properties[@"PixelHeight"] doubleValue]);
            if([properties[@"Orientation"] integerValue]>=5) size=NSMakeSize(size.height,size.width);
            if(size.width<1 || size.height<1 || size.width>100000 || size.height>100000 || size.width*size.height>100000000) error=DPEaselError(@"Choose an image with valid dimensions below 100 megapixels.");
            if(api.count) frameCount=api.count(source);
        }
        if(source) CFRelease(source);
        if(!error) {
            [NSFileManager.defaultManager createDirectoryAtURL:destination.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];
            if(!error) [NSFileManager.defaultManager copyItemAtURL:url toURL:destination error:&error];
        }
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            if(!error) [self.imageInfo setObject:@{@"frames":@(frameCount)} forKey:destination.path];
            if(document.deleted) { [self discardUnplacedAsset:asset document:document]; completion(nil,NSZeroSize,DPEaselError(@"The Easel was deleted before the import finished.")); }
            else completion(error ? nil : asset,size,error);
        }];
    }}];
}
@end
