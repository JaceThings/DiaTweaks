#import "Library.h"
#import <ImageIO/ImageIO.h>
#import <dlfcn.h>
BOOL DPLibraryIsMovieURL(NSURL *url);

NSImage *DPLibraryVideoStill(NSURL *url);
void DPLibraryThumbnail(NSURL *url, void (^completion)(NSImage *)) {
    static NSCache *cache;
    static NSOperationQueue *queue;
    static NSMutableDictionary<NSString *,NSMutableArray *> *pending;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pending = [NSMutableDictionary new];
        cache = [NSCache new]; cache.totalCostLimit = 24 * 1024 * 1024;
        queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 2;
        queue.qualityOfService = NSQualityOfServiceUtility;
    });
    if (!url.isFileURL) { completion(nil); return; }
    BOOL movie = DPLibraryIsMovieURL(url); // Classification stays on the caller's main queue.
    NSString *request = url.path;
    // Coalesce decoding, but finish every visible/reused item's request. Dropping
    // callers at saturation leaves placeholders until a later view reload.
    if (pending[request]) { [pending[request] addObject:[completion copy]]; return; }
    pending[request] = [NSMutableArray arrayWithObject:[completion copy]];
    [queue addOperationWithBlock:^{
        @autoreleasepool {
            static void *imageIO;
            static dispatch_once_t loader;
            dispatch_once(&loader, ^{ imageIO = dlopen("/System/Library/Frameworks/ImageIO.framework/ImageIO",RTLD_LAZY); });
            CGImageSourceRef (*openSource)(CFURLRef,CFDictionaryRef) = dlsym(imageIO,"CGImageSourceCreateWithURL");
            CGImageRef (*thumbnail)(CGImageSourceRef,size_t,CFDictionaryRef) = dlsym(imageIO,"CGImageSourceCreateThumbnailAtIndex");
            NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil];
            NSString *key = [NSString stringWithFormat:@"%@:%@:%@",request,attributes[NSFileModificationDate],attributes[NSFileSize]];
            NSImage *image = attributes ? [cache objectForKey:key] : nil;
            if (!image && attributes && openSource && thumbnail) {
                NSDictionary *options = @{@"kCGImageSourceShouldCache":@NO};
                CGImageSourceRef source = openSource((__bridge CFURLRef)url,(__bridge CFDictionaryRef)options);
                if (source) {
                    NSDictionary *settings = @{@"kCGImageSourceCreateThumbnailFromImageAlways":@YES,
                        @"kCGImageSourceThumbnailMaxPixelSize":@420,@"kCGImageSourceCreateThumbnailWithTransform":@YES};
                    CGImageRef pixels = thumbnail(source,0,(__bridge CFDictionaryRef)settings);
                    if (pixels) { image = [[NSImage alloc] initWithCGImage:pixels size:NSZeroSize]; CGImageRelease(pixels); }
                    CFRelease(source);
                }
            }
            if (!image && attributes && movie) image = DPLibraryVideoStill(url);
            if (image) [cache setObject:image forKey:key cost:420*420*4];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSArray *callbacks = pending[request]; [pending removeObjectForKey:request];
                for (void (^callback)(NSImage *) in callbacks) callback(image);
            });
        }
    }];
}
