#import "HostInternal.h"
#import <objc/runtime.h>
static char DPMetadataKey;
static NSHashTable *DPMetadataStates;
@interface DPEaselRestoredMetadata : NSObject
@property(weak) id contents;
@property NSString *identifier,*title;
@property BOOL loading,failed;
@property NSUInteger generation;
@property id observer;
@property NSTimer *publication;
- (void)publish;
- (void)load;
@end
@implementation DPEaselRestoredMetadata
- (void)dealloc { [self.publication invalidate]; if(self.observer) [NSNotificationCenter.defaultCenter removeObserver:self.observer]; }
- (void)publish {
    [self.publication invalidate]; __weak DPEaselRestoredMetadata *weak=self;
    self.publication=[NSTimer timerWithTimeInterval:.25 repeats:NO block:^(NSTimer *timer){
        DPEaselRestoredMetadata *state=weak; state.publication=nil; id contents=state.contents;
        NSURL *url=DPEaselRead(contents,@"url");
        if(!contents || ![url isKindOfClass:NSURL.class] || ![[DPEaselStore.shared identifierForURL:url] isEqual:state.identifier]) return;
        for(NSString *key in @[@"title",@"favicon"]) { [contents willChangeValueForKey:key]; [contents didChangeValueForKey:key]; }
    }];
    [NSRunLoop.mainRunLoop addTimer:self.publication forMode:NSRunLoopCommonModes];
}
- (void)load {
    if(self.loading || self.failed || self.title) return;
    self.loading=YES; NSUInteger generation=self.generation; NSString *identifier=self.identifier;
    NSURL *url=[[[DPEaselStore.shared pageURL:identifier] URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"summary.json"];
    static NSOperationQueue *queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=NSOperationQueue.new; queue.maxConcurrentOperationCount=2; queue.qualityOfService=NSQualityOfServiceUtility; });
    __weak DPEaselRestoredMetadata *weak=self;
    [queue addOperationWithBlock:^{ @autoreleasepool {
        NSNumber *size=nil; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        BOOL safe=[url.URLByResolvingSymlinksInPath.path isEqual:url.path] && size && size.unsignedLongLongValue<=65536;
        NSData *data=safe ? [NSData dataWithContentsOfURL:url options:0 error:nil] : nil;
        NSDictionary *record=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *title=[record isKindOfClass:NSDictionary.class] && [record[@"id"] isEqual:identifier] && [record[@"title"] isKindOfClass:NSString.class] ? DPEaselDisplayTitle(record[@"title"]) : nil;
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            DPEaselRestoredMetadata *state=weak; if(!state) return; state.loading=NO;
            if(state.generation!=generation) return;
            state.title=title; state.failed=title==nil; [state publish];
        }];
    }}];
}
@end
NSString *DPEaselMetadataTitle(id contents) {
    if(!DPEasels.on || !NSThread.isMainThread) return nil;
    NSURL *url=DPEaselRead(contents,@"url");
    if(![url isKindOfClass:NSURL.class]) return nil;
    NSString *identifier=[DPEaselStore.shared identifierForURL:url]; if(!identifier) return nil;
    DPEaselRestoredMetadata *state=objc_getAssociatedObject(contents,&DPMetadataKey);
    if(![state.identifier isEqual:identifier]) {
        state=DPEaselRestoredMetadata.new; state.contents=contents; state.identifier=identifier;
        objc_setAssociatedObject(contents,&DPMetadataKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if(!DPMetadataStates) DPMetadataStates=NSHashTable.weakObjectsHashTable; [DPMetadataStates addObject:state];
        __weak DPEaselRestoredMetadata *weak=state;
        state.observer=[NSNotificationCenter.defaultCenter addObserverForName:DPEaselChanged object:nil queue:nil usingBlock:^(NSNotification *note){
            DPEaselRestoredMetadata *owner=weak; DPEaselDocument *document=note.object;
            if(!owner || ![document.identifier isEqual:owner.identifier]) return;
            owner.generation++; owner.failed=document.deleted; owner.title=document.deleted ? nil : DPEaselDisplayTitle(document.title); [owner publish];
        }];
    }
    DPEaselDocument *document=[DPEaselStore.shared cachedDocumentForURL:url];
    if(document) {
        if(document.deleted) return nil;
        NSString *title=DPEaselDisplayTitle(document.title);
        if(![state.title isEqual:title]) { state.generation++; state.title=title; }
    } else [state load];
    return state.title ?: @"Untitled";
}
void DPEaselRefreshMetadata(void) { for(DPEaselRestoredMetadata *state in DPMetadataStates.allObjects) [state publish]; }
