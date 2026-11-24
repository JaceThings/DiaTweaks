#import "Canvas.h"
#import "Clipboard.h"
static NSString *const DPObjectsPasteboard=@"com.diatweaks.easels.objects";
@implementation DPEaselCanvas (Clipboard)
- (void)copy:(id)sender {
    NSMutableArray *objects=NSMutableArray.new,*text=NSMutableArray.new;
    for(NSDictionary *object in self.document.objects) if([self.selection containsObject:object[@"id"]]) {
        [objects addObject:object]; if(object[@"text"]) [text addObject:object[@"text"]];
    }
    if(!objects.count) return;
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"document":self.document.identifier,@"objects":objects} options:0 error:nil];
    NSPasteboard *pasteboard=NSPasteboard.generalPasteboard; [pasteboard clearContents];
    NSPasteboardItem *item=NSPasteboardItem.new; [item setData:data forType:DPObjectsPasteboard];
    if(text.count) [item setString:[text componentsJoinedByString:@"\n"] forType:NSPasteboardTypeString];
    if(objects.count==1 && [objects[0][@"type"] isEqual:@"image"]) {
        DPEaselProvideOriginalImage(item,objects[0][@"asset"],self.document.identifier);
    }
    [pasteboard writeObjects:@[item]];
}
- (void)cut:(id)sender { if(!self.selection.count) return; [self copy:sender]; [self delete:sender]; }
- (void)paste:(id)sender {
    NSPasteboard *pasteboard=NSPasteboard.generalPasteboard; NSData *data=[pasteboard dataForType:DPObjectsPasteboard];
    NSDictionary *payload=data.length<=16*1024*1024 && data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if([payload isKindOfClass:NSDictionary.class] && DPEaselUUID(payload[@"document"])) {
        NSArray *source=payload[@"objects"]; NSMutableDictionary *candidate=[self.document.snapshot mutableCopy]; candidate[@"objects"]=source ?: @[];
        if(!DPEaselValidSnapshot(candidate) || !source.count) return;
        NSMutableArray *copies=NSMutableArray.new;
        DPEaselDocument *destination=self.document; NSMutableArray *imported=NSMutableArray.new;
        dispatch_group_t imports=dispatch_group_create(); __block BOOL failed=NO;
        for(NSDictionary *object in source) {
            NSMutableDictionary *copy=[object mutableCopy]; [copy removeObjectForKey:@"isTitle"]; copy[@"id"]=NSUUID.UUID.UUIDString; [copies addObject:copy];
            if(![object[@"type"] isEqual:@"image"]) continue;
            NSURL *url=[DPEaselStore.shared readableAssetURL:object[@"asset"] document:payload[@"document"]];
            dispatch_group_enter(imports);
            [DPEaselStore.shared importImage:url document:self.document completion:^(NSString *asset,NSSize size,NSError *error) {
                if(asset) { copy[@"asset"]=asset; [imported addObject:asset]; } else failed=YES; dispatch_group_leave(imports);
            }];
        }
        __weak DPEaselCanvas *weak=self;
        dispatch_group_notify(imports,dispatch_get_main_queue(),^{
            DPEaselCanvas *canvas=weak; if(!canvas || canvas.document.deleted || failed) {
                for(NSString *asset in imported) [DPEaselStore.shared discardUnplacedAsset:asset document:destination]; return;
            }
            NSMutableArray *objects=[canvas.document.objects mutableCopy]; NSUInteger order=0;
            for(NSDictionary *object in objects) order=MAX(order,[object[@"order"] unsignedIntegerValue]+1);
            [canvas.selection removeAllObjects];
            for(NSMutableDictionary *copy in copies) {
                NSRect rect=NSOffsetRect(DPEaselObjectRect(copy),16,16);
                rect.origin.x=MAX(0,MIN(rect.origin.x,NSWidth(canvas.bounds)-rect.size.width)); rect.origin.y=MAX(0,MIN(rect.origin.y,NSHeight(canvas.bounds)-rect.size.height));
                NSMutableDictionary *placed=[DPEaselTransformObject(copy,rect) mutableCopy]; placed[@"order"]=@(order); placed[@"z"]=@(order++);
                [objects addObject:placed]; [canvas.selection addObject:placed[@"id"]];
            }
            [canvas commit:objects action:@"Paste"];
            for(NSString *asset in imported) [DPEaselStore.shared discardUnplacedAsset:asset document:destination]; // Retains assets actually placed by the commit.
        });
        return;
    }
    if([self pasteImageFromPasteboard:pasteboard atPoint:NSMakePoint(NSMinX(self.visibleRect)+24,NSMinY(self.visibleRect)+24)]) return;
    NSString *text=[pasteboard stringForType:NSPasteboardTypeString]; if(!text.length || text.length>1000000) return;
    NSUInteger order=0; for(NSDictionary *object in self.document.objects) order=MAX(order,[object[@"order"] unsignedIntegerValue]+1);
    NSDictionary *object=DPEaselText(text,NSMakeRect(NSMinX(self.visibleRect)+24,NSMinY(self.visibleRect)+24,300,120),order,NO);
    [self.selection setSet:[NSSet setWithObject:object[@"id"]]]; [self commit:[self.document.objects arrayByAddingObject:object] action:@"Paste Text"];
}
@end
