#import "Library.h"
#import <objc/message.h>
NSImage *DPLibraryFaviconFromDatabase(NSString *,NSURL *);
@interface DPLibraryIconRequest : NSObject
@property NSString *key,*profile;
@property NSURL *url;
@property NSMutableArray *callbacks;
@property BOOL fallback,finished;
@end
@implementation DPLibraryIconRequest @end
static NSCache *DPIcons;
static NSMutableDictionary<NSString *,DPLibraryIconRequest *> *DPIconRequests;
static NSMutableDictionary<NSString *,NSDate *> *DPFailedIcons;
static NSMutableArray<DPLibraryIconRequest *> *DPIconQueue;
static NSUInteger DPIconActive;
static void DPPumpIcons(void);
static void DPFinishIcon(DPLibraryIconRequest *request,NSImage *image) {
    if(request.finished) return; request.finished=YES;
    if(image) { [DPIcons setObject:image forKey:request.key cost:MAX(4096,(NSUInteger)(image.size.width*image.size.height*4))]; [DPFailedIcons removeObjectForKey:request.key]; }
    else { if(DPFailedIcons.count>=512) [DPFailedIcons removeObjectForKey:DPFailedIcons.allKeys.firstObject]; DPFailedIcons[request.key]=NSDate.date; }
    [DPIconRequests removeObjectForKey:request.key]; DPIconActive--;
    for(void (^callback)(NSImage *) in request.callbacks) callback(image);
    DPPumpIcons();
}
static void DPFallbackIcon(DPLibraryIconRequest *request) {
    if(request.finished || request.fallback) return; request.fallback=YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        NSImage *image=DPLibraryFaviconFromDatabase(request.profile,request.url);
        dispatch_async(dispatch_get_main_queue(),^{ DPFinishIcon(request,image); });
    });
}
static void DPPumpIcons(void) {
    while(DPIconActive<4 && DPIconQueue.count) {
        DPLibraryIconRequest *request=DPIconQueue.firstObject; [DPIconQueue removeObjectAtIndex:0]; DPIconActive++;
        id context=DPLibraryNativeContext(request.profile); SEL selector=NSSelectorFromString(@"favicon:completion:");
        if(![context respondsToSelector:selector]) { DPFallbackIcon(request); continue; }
        ((void (*)(id,SEL,id,id))objc_msgSend)(context,selector,request.url,^(NSImage *image) {
            dispatch_async(dispatch_get_main_queue(),^{ if(image) DPFinishIcon(request,image); else DPFallbackIcon(request); });
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,450*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ DPFallbackIcon(request); });
    }
}
void DPLibraryInvalidateFavicons(NSString *profile) {
    for(NSString *key in DPFailedIcons.allKeys) if([key hasPrefix:[profile stringByAppendingString:@"|"]]) [DPFailedIcons removeObjectForKey:key];
}
void DPLibraryFavicon(NSString *profile,NSString *source,void (^completion)(NSImage *)) {
    static dispatch_once_t once;
    dispatch_once(&once,^{ DPIcons=NSCache.new; DPIcons.countLimit=512; DPIcons.totalCostLimit=8*1024*1024; DPIconRequests=NSMutableDictionary.new; DPFailedIcons=NSMutableDictionary.new; DPIconQueue=NSMutableArray.new; });
    NSURL *url=source.length ? [NSURL URLWithString:source] : nil;
    if(!profile.length || !url.host.length || ![@[@"https",@"http"] containsObject:url.scheme.lowercaseString]) { completion(nil); return; }
    NSString *key=[NSString stringWithFormat:@"%@|%@://%@:%@",profile,url.scheme,url.host,url.port ?: @0];
    NSImage *known=[DPIcons objectForKey:key]; if(known) { completion(known); return; }
    NSDate *failed=DPFailedIcons[key]; if(failed && -failed.timeIntervalSinceNow<5) { completion(nil); return; }
    DPLibraryIconRequest *request=DPIconRequests[key];
    if(request) { [request.callbacks addObject:[completion copy]]; return; }
    request=DPLibraryIconRequest.new; request.key=key; request.profile=profile; request.url=url; request.callbacks=[NSMutableArray arrayWithObject:[completion copy]];
    DPIconRequests[key]=request; [DPIconQueue addObject:request]; DPPumpIcons();
}
