#import "Portable.h"
#import "StoreInternal.h"
#import "Canvas.h"
static NSData *DPPreview(NSDictionary *snapshot,NSDictionary *assets) {
    DPEaselDocument *document=[[DPEaselDocument alloc] initWithSnapshot:snapshot];
    NSSize size=document.canvasSize; CGFloat scale=MIN(2,MIN(4096/size.width,4096/size.height));
    NSInteger width=ceil(size.width*scale),height=ceil(size.height*scale);
    NSBitmapImageRep *pixels=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    if(!pixels) return nil;
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,size.width,size.height)]; canvas.document=document;
    for(NSString *key in assets) { NSImage *image=[[NSImage alloc] initWithData:assets[key]]; if(!image || !image.isValid) return nil; [canvas.images setObject:image forKey:key]; }
    [NSGraphicsContext saveGraphicsState]; NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:pixels];
    NSAffineTransform *transform=NSAffineTransform.transform; [transform translateXBy:0 yBy:height]; [transform scaleXBy:scale yBy:-scale]; [transform concat];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithCGContext:NSGraphicsContext.currentContext.CGContext flipped:YES];
    [NSColor.textBackgroundColor setFill]; NSRectFill(canvas.bounds);
    [canvas drawObjects:document.objects inRect:canvas.bounds selection:NO]; [NSGraphicsContext restoreGraphicsState];
    return [pixels representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}
@implementation DPEaselStore (PortableExport)
- (void)exportPortable:(DPEaselDocument *)document editable:(BOOL)editable toURL:(NSURL *)url completion:(void (^)(NSError *))completion {
    NSAssert(NSThread.isMainThread,@"Freeze document edits before exporting");
    if(!document || document.deleted || !url.isFileURL) { completion(DPEaselError(@"This Easel cannot be exported.")); return; }
    [DPEaselHost finishEditingDocument:document]; NSDictionary *snapshot=document.snapshot;
    NSMutableSet *required=NSMutableSet.new; for(NSDictionary *object in snapshot[@"objects"]) if([object[@"type"] isEqual:@"image"]) [required addObject:object[@"asset"]];
    [self.queue addOperationWithBlock:^{ @autoreleasepool {
        NSError *error=nil; NSMutableDictionary *assets=NSMutableDictionary.new; NSUInteger total=0;
        for(NSString *key in required) {
            NSURL *source=[self readableAssetURL:key document:document.identifier];
            NSNumber *size=nil; [source getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
            if(error || size.unsignedLongLongValue>100*1024*1024 || total+size.unsignedLongLongValue>100*1024*1024) { error=error ?: DPEaselError(@"The images are too large for a portable Easel (100 MB limit)."); break; }
            NSData *data=[NSData dataWithContentsOfURL:source options:0 error:&error]; if(!data) break;
            total+=data.length; assets[key]=data;
        }
        dispatch_async(dispatch_get_main_queue(),^{
            __block NSData *preview=nil,*darkPreview=nil;
            if(!error) {
                [[NSAppearance appearanceNamed:NSAppearanceNameAqua] performAsCurrentDrawingAppearance:^{ preview=DPPreview(snapshot,assets); }];
                [[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua] performAsCurrentDrawingAppearance:^{ darkPreview=DPPreview(snapshot,assets); }];
            }
            [self.queue addOperationWithBlock:^{ @autoreleasepool {
                NSError *writeError=error; NSData *html=writeError ? nil : DPEaselPortableHTML(snapshot,assets,preview,darkPreview,editable,&writeError);
                if(html) [html writeToURL:url options:NSDataWritingAtomic error:&writeError];
                dispatch_async(dispatch_get_main_queue(),^{ completion(writeError); });
            }}];
        });
    }}];
}
@end
