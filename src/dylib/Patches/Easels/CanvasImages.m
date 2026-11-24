#import "Canvas.h"
@implementation DPEaselCanvas (Images)
- (void)requestImage:(NSDictionary *)object {
    NSString *asset=object[@"asset"];
    if(!asset || [self.imageRequests containsObject:asset] || [self.failedImages containsObject:asset]) return;
    [self.imageRequests addObject:asset];
    NSString *identifier=self.document.identifier;
    NSURL *url=[DPEaselStore.shared assetURL:asset document:identifier];
    __weak DPEaselCanvas *weak=self;
    [DPEaselImageCache.shared thumbnail:url completion:^(NSImage *image) {
        DPEaselCanvas *canvas=weak; if(!canvas || canvas.document.deleted || ![canvas.document.identifier isEqual:identifier]) return;
        [canvas.imageRequests removeObject:asset];
        if(image) [canvas.images setObject:image forKey:asset cost:(NSUInteger)(image.size.width*image.size.height*4)];
        else [canvas.failedImages addObject:asset];
        canvas.needsDisplay=YES;
    }];
}
- (void)placeImage:(NSString *)asset size:(NSSize)size atPoint:(NSPoint)point {
    if(!asset || size.width<1 || size.height<1) return;
    CGFloat scale=MIN(1,MIN(420/size.width,420/size.height)); size.width*=scale; size.height*=scale;
    CGFloat x=MAX(0,MIN(point.x,NSWidth(self.bounds)-size.width)),y=MAX(0,MIN(point.y,NSHeight(self.bounds)-size.height));
    NSUInteger order=0; for(NSDictionary *object in self.document.objects) order=MAX(order,[object[@"order"] unsignedIntegerValue]+1);
    BOOL animated=[[DPEaselStore.shared imageInfoForAsset:asset document:self.document.identifier][@"frames"] unsignedIntegerValue]>1;
    NSDictionary *object=@{@"id":NSUUID.UUID.UUIDString,@"type":@"image",@"asset":asset,@"animated":@(animated),@"order":@(order),@"z":@(order),@"rect":DPEaselRectArray(NSMakeRect(x,y,size.width,size.height))};
    [self.selection setSet:[NSSet setWithObject:object[@"id"]]];
    [self commit:[self.document.objects arrayByAddingObject:object] action:@"Add Image"];
    BOOL committed=[[self.document.objects valueForKey:@"id"] containsObject:object[@"id"]];
    if(committed && [self.pendingAsset isEqual:asset]) self.pendingAssetCommitted=YES;
    if(!committed) {
        [DPEaselStore.shared discardUnplacedAsset:asset document:self.document];
        [self reportImportError:[NSError errorWithDomain:@"DiaTweaks.Easels" code:1 userInfo:@{NSLocalizedDescriptionKey:@"The image could not be added to this Easel. Its existing contents have been kept."}]];
    }
    if(!committed || ![self.tool isEqual:@"image"]) self.pendingAsset=nil; [self.window invalidateCursorRectsForView:self]; if(self.selectionChanged) self.selectionChanged();
}
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender { return self.document.deleted ? NSDragOperationNone : NSDragOperationCopy; }
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSArray *urls=[sender.draggingPasteboard readObjectsForClasses:@[NSURL.class] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES}];
    NSPoint point=[self convertPoint:sender.draggingLocation fromView:nil];
    if(!urls.count) return [self pasteImageFromPasteboard:sender.draggingPasteboard atPoint:point];
    __weak DPEaselCanvas *weak=self;
    DPEaselDocument *document=self.document;
    for(NSURL *url in urls) {
        [DPEaselStore.shared importImage:url document:document completion:^(NSString *asset,NSSize size,NSError *error) {
            DPEaselCanvas *canvas=weak;
            if(asset && canvas && !canvas.document.deleted) [canvas placeImage:asset size:size atPoint:point];
            else { if(asset) [DPEaselStore.shared discardUnplacedAsset:asset document:document]; [canvas reportImportError:error]; }
        }];
        point.x+=20; point.y+=20;
    }
    return YES;
}
@end
