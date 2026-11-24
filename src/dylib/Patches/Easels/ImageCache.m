#import "Assets.h"
#import "ImageIO.h"
@implementation DPEaselImageCache {
    NSCache *_cache;
    NSOperationQueue *_queue;
    NSMutableDictionary *_pending;
    NSUInteger _generation;
}
+ (instancetype)shared {
    static DPEaselImageCache *cache; static dispatch_once_t once;
    dispatch_once(&once,^{ cache=[self new]; }); return cache;
}
- (instancetype)init {
    if((self=[super init])) {
        _cache=NSCache.new; _cache.totalCostLimit=32*1024*1024;
        _queue=NSOperationQueue.new; _queue.maxConcurrentOperationCount=2; _queue.qualityOfService=NSQualityOfServiceUtility;
        _pending=NSMutableDictionary.new;
    }
    return self;
}
- (void)clear { NSAssert(NSThread.isMainThread,@"Image registry is main-thread owned"); _generation++; [_cache removeAllObjects]; }
- (void)thumbnail:(NSURL *)url completion:(void (^)(NSImage *))completion {
    NSAssert(NSThread.isMainThread,@"Image registry is main-thread owned");
    if(!url.isFileURL) { completion(nil); return; }
    NSString *key=url.path;
    NSImage *cached=[_cache objectForKey:key];
    if(cached) { completion(cached); return; }
    if(_pending[key]) { [_pending[key] addObject:[completion copy]]; return; }
    _pending[key]=[NSMutableArray arrayWithObject:[completion copy]];
    NSUInteger generation=_generation;
    [_queue addOperationWithBlock:^{ @autoreleasepool {
        DPEaselImageFunctions api=DPEaselImageIO();
        CGImageSourceRef source=api.open ? api.open((__bridge CFURLRef)url,(__bridge CFDictionaryRef)@{@"kCGImageSourceShouldCache":@NO}) : nil;
        NSDictionary *options=@{@"kCGImageSourceCreateThumbnailFromImageAlways":@YES,@"kCGImageSourceThumbnailMaxPixelSize":@1024,@"kCGImageSourceCreateThumbnailWithTransform":@YES};
        CGImageRef pixels=source && api.thumbnail ? api.thumbnail(source,0,(__bridge CFDictionaryRef)options) : nil;
        NSImage *image=pixels ? [[NSImage alloc] initWithCGImage:pixels size:NSZeroSize] : nil;
        NSUInteger cost=pixels ? CGImageGetBytesPerRow(pixels)*CGImageGetHeight(pixels) : 0;
        if(pixels) CGImageRelease(pixels); if(source) CFRelease(source);
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            if(image && generation==self->_generation) [self->_cache setObject:image forKey:key cost:cost];
            NSArray *callbacks=self->_pending[key]; [self->_pending removeObjectForKey:key];
            for(void (^callback)(NSImage *) in callbacks) callback(generation==self->_generation ? image : nil);
        }];
    }}];
}
@end
