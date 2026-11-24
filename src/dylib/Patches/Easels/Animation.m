#import "Animation.h"
#import "ImageIO.h"
@implementation DPEaselFrameSource {
    CGImageSourceRef _source;
}
- (void)dealloc { if(_source) CFRelease(_source); }
- (BOOL)request:(NSUInteger)index completion:(void (^)(NSImage *,NSTimeInterval,NSUInteger))completion {
    static NSOperationQueue *queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=NSOperationQueue.new; queue.maxConcurrentOperationCount=2; queue.qualityOfService=NSQualityOfServiceUtility; });
    // Drop overloaded frame requests instead of accumulating a playback queue.
    if(queue.operationCount>=2) return NO;
    [queue addOperationWithBlock:^{ @autoreleasepool {
        DPEaselImageFunctions api=DPEaselImageIO();
        if(!self->_source && api.open) self->_source=api.open((__bridge CFURLRef)self.url,(__bridge CFDictionaryRef)@{@"kCGImageSourceShouldCache":@NO});
        NSUInteger count=self->_source && api.count ? api.count(self->_source) : 0;
        NSUInteger frame=count ? index%count : 0;
        NSDictionary *metadata=self->_source && api.properties ? CFBridgingRelease(api.properties(self->_source,frame,NULL)) : nil;
        NSDictionary *gif=metadata[@"{GIF}"];
        double delay=[gif[@"UnclampedDelayTime"] doubleValue] ?: [gif[@"DelayTime"] doubleValue];
        delay=delay<.02 ? .1 : MIN(10,delay);
        NSDictionary *options=@{@"kCGImageSourceCreateThumbnailFromImageAlways":@YES,@"kCGImageSourceThumbnailMaxPixelSize":@720,@"kCGImageSourceCreateThumbnailWithTransform":@YES};
        CGImageRef pixels=count && api.thumbnail ? api.thumbnail(self->_source,frame,(__bridge CFDictionaryRef)options) : NULL;
        NSImage *image=pixels ? [[NSImage alloc] initWithCGImage:pixels size:NSZeroSize] : nil;
        if(pixels) CGImageRelease(pixels);
        [NSOperationQueue.mainQueue addOperationWithBlock:^{ completion(image,delay,count); }];
    }}];
    return YES;
}
@end
