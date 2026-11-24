#import "Clipboard.h"
#import "ImageIO.h"
@interface DPEaselOriginalImageProvider : NSObject <NSPasteboardItemDataProvider>
@property NSString *asset,*document;
@end
@implementation DPEaselOriginalImageProvider
- (void)pasteboard:(NSPasteboard *)pasteboard item:(NSPasteboardItem *)item provideDataForType:(NSPasteboardType)type {
    NSURL *url=[DPEaselStore.shared readableAssetURL:self.asset document:self.document];
    NSNumber *size=nil; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if(size.unsignedLongLongValue>100*1024*1024) return;
    NSData *data=[NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if(data) [item setData:data forType:type];
}
@end
void DPEaselProvideOriginalImage(NSPasteboardItem *item,NSString *asset,NSString *document) {
    NSURL *url=[DPEaselStore.shared readableAssetURL:asset document:document];
    DPEaselImageFunctions api=DPEaselImageIO();
    CGImageSourceRef source=api.open ? api.open((__bridge CFURLRef)url,NULL) : NULL;
    NSString *type=source && api.type ? [(__bridge NSString *)api.type(source) copy] : nil;
    if(source) CFRelease(source);
    if(![@[@"public.png",@"public.jpeg",@"com.compuserve.gif"] containsObject:type ?: @""]) return;
    DPEaselOriginalImageProvider *provider=DPEaselOriginalImageProvider.new; provider.asset=asset; provider.document=document;
    [item setDataProvider:provider forTypes:@[type]];
}
