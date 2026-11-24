#import "Canvas.h"
#import "ImageIO.h"
static NSData *DPEaselConvertTIFF(NSData *data) {
    void *handle=dlopen("/System/Library/Frameworks/ImageIO.framework/ImageIO",RTLD_LAZY);
    CGImageSourceRef (*create)(CFDataRef,CFDictionaryRef)=dlsym(handle,"CGImageSourceCreateWithData");
    DPEaselImageFunctions api=DPEaselImageIO();
    CGImageSourceRef source=create ? create((__bridge CFDataRef)data,(__bridge CFDictionaryRef)@{@"kCGImageSourceShouldCache":@NO}) : NULL;
    if(!source) return nil;
    NSDictionary *info=api.properties ? CFBridgingRelease(api.properties(source,0,NULL)) : nil;
    double width=[info[@"PixelWidth"] doubleValue],height=[info[@"PixelHeight"] doubleValue];
    NSData *png=nil;
    // Native clipboard TIFFs are decoded only on demand and on the worker.
    // Reject extreme dimensions before allocating a full raster.
    if(width>0 && height>0 && width*height<=25000000 && MAX(width,height)<=16384 && api.thumbnail) {
        NSDictionary *options=@{@"kCGImageSourceCreateThumbnailFromImageAlways":@YES,@"kCGImageSourceThumbnailMaxPixelSize":@(MAX(width,height)),@"kCGImageSourceCreateThumbnailWithTransform":@YES};
        CGImageRef pixels=api.thumbnail(source,0,(__bridge CFDictionaryRef)options);
        if(pixels) { png=[[[NSBitmapImageRep alloc] initWithCGImage:pixels] representationUsingType:NSBitmapImageFileTypePNG properties:@{}]; CGImageRelease(pixels); }
    }
    CFRelease(source); return png;
}
@implementation DPEaselCanvas (PasteImage)
- (BOOL)pasteImageFromPasteboard:(NSPasteboard *)pasteboard atPoint:(NSPoint)point {
    NSString *type=[pasteboard availableTypeFromArray:@[NSPasteboardTypePNG,@"public.jpeg",@"com.compuserve.gif",NSPasteboardTypeTIFF]];
    NSData *data=type ? [pasteboard dataForType:type] : nil;
    if(!data.length || data.length>100*1024*1024 || self.document.deleted) return NO;
    __weak DPEaselCanvas *weak=self;
    DPEaselDocument *document=self.document;
    static NSOperationQueue *queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=NSOperationQueue.new; queue.maxConcurrentOperationCount=1; queue.qualityOfService=NSQualityOfServiceUtility; });
    if(queue.operationCount>=2) { NSBeep(); return YES; }
    [queue addOperationWithBlock:^{ @autoreleasepool {
        NSData *image=[type isEqual:NSPasteboardTypeTIFF] ? DPEaselConvertTIFF(data) : data;
        NSURL *incoming=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSError *failure=nil;
        if(!image) failure=[NSError errorWithDomain:@"DiaTweaks.Easels" code:1 userInfo:@{NSLocalizedDescriptionKey:@"The clipboard image could not be decoded. Try a PNG, JPEG or GIF."}];
        else [image writeToURL:incoming options:NSDataWritingAtomic error:&failure];
        if(failure) { [NSOperationQueue.mainQueue addOperationWithBlock:^{ [weak reportImportError:failure]; }]; return; }
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            DPEaselCanvas *canvas=weak;
            if(!canvas || canvas.document.deleted) { [NSFileManager.defaultManager removeItemAtURL:incoming error:nil]; return; }
            [DPEaselStore.shared importImage:incoming document:canvas.document completion:^(NSString *asset,NSSize size,NSError *error){
                [NSFileManager.defaultManager removeItemAtURL:incoming error:nil];
                DPEaselCanvas *owner=weak; if(asset && owner && !owner.document.deleted) [owner placeImage:asset size:size atPoint:point];
                else { if(asset) [DPEaselStore.shared discardUnplacedAsset:asset document:document]; [owner reportImportError:error]; }
            }];
        }];
    }}];
    return YES;
}
@end
