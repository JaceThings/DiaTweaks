#import "Patches/ChatGPTPreview/Cache.h"
#import "TabIntegrations/Internal.h"

@interface DPCacheFixturePage : NSObject
@property(nonatomic, strong) id contents, browser;
@property(nonatomic, copy) NSDictionary *snapshot;
@property(nonatomic) NSTimeInterval receivedAt;
@property(nonatomic) DPTabIntegration *integration;
@end
@implementation DPCacheFixturePage
@end
static NSDictionary *snapshot(NSString *scope, BOOL loaded, NSArray *rows) {
    return @{@"scopeKey":scope, @"sourceLoaded":@(loaded), @"sourceStatus":loaded ? (rows.count ? @"ready" : @"empty") : @"no-sidebar-data", @"recent":rows, @"pinned":NSNull.null};
}
int main(void) { @autoreleasepool {
    NSDictionary *row = @{@"id":@"a", @"title":@"Example", @"activity":@"generating", @"unread":@YES};
    NSDictionary *good = snapshot(@"account:first", YES, @[row]);
    DPTabIntegrationCache *cache = [DPTabIntegrationCache new];
    NSDictionary *value = DPChatGPTCachePresentation(cache, good, 10, 10);
    NSCAssert([value[@"state"] isEqual:@"live"] && [value[@"rows"] count] == 1, @"successful metadata populates cache");
    value = DPChatGPTCachePresentation(cache, nil, 0, 20);
    NSCAssert([value[@"state"] isEqual:@"cached"] && [value[@"rows"] count] == 1, @"transport failure preserves recent titles");
    NSCAssert([value[@"rows"][0][@"activity"] isEqual:@"stale"] && ![value[@"rows"][0][@"unread"] boolValue], @"cached rows never show a stale spinner or unread dot");
    value = DPChatGPTCachePresentation(cache, snapshot(@"account:first", NO, @[]), 21, 21);
    NSCAssert([value[@"state"] isEqual:@"cached"] && [value[@"rows"] count] == 1, @"missing sidebar does not erase last success");
    value = DPChatGPTCachePresentation(cache, good, 30, 30);
    NSCAssert([value[@"state"] isEqual:@"live"] && [value[@"rows"][0][@"activity"] isEqual:@"generating"], @"fresh observations restore live status");
    value = DPChatGPTCachePresentation(cache, snapshot(@"account:first", YES, @[]), 31, 31);
    NSCAssert([value[@"rows"] count] == 0 && [value[@"state"] isEqual:@"live"], @"confirmed empty sidebar clears previous list");
    DPChatGPTCachePresentation(cache, good, 40, 40);
    value = DPChatGPTCachePresentation(cache, snapshot(@"account:second", NO, @[]), 41, 41);
    NSCAssert([value[@"state"] isEqual:@"missing"] && ![value[@"rows"] count], @"observed account change clears the old cache even before data is ready");
    DPChatGPTCachePresentation(cache, good, 50, 50);
    value = DPChatGPTCachePresentation(cache, snapshot(@"transient:new-document", NO, @[]), 51, 51);
    NSCAssert([value[@"state"] isEqual:@"missing"], @"logout or unknown-account document replacement discards old identity");
    DPChatGPTCachePresentation(cache, good, 60, 60);
    NSCAssert([DPChatGPTCachePresentation(cache, nil, 0, 3661)[@"state"] isEqual:@"missing"], @"unreachable data expires instead of preserving account metadata indefinitely");
    NSCAssert([DPChatGPTEmptyMessage(@"missing", 0) containsString:@"Loading"], @"initial wait is bounded");
    NSCAssert(![DPChatGPTEmptyMessage(@"missing", 6) containsString:@"Loading"], @"cache miss leaves loading after the deadline");
    DPTabIntegration site = {0};
    DPCacheFixturePage *first = [DPCacheFixturePage new], *second = [DPCacheFixturePage new];
    first.contents = [NSObject new]; first.browser = [NSObject new]; first.snapshot = good; first.receivedAt = NSDate.timeIntervalSinceReferenceDate;
    first.integration = second.integration = &site;
    second.contents = [NSObject new]; second.browser = first.browser;
    DPChatGPTSnapshotChanged((id)first); // Store success before any hover/card exists.
    DPTabIntegrationCache *saved = DPTabIntegrationCacheForPage((id)first);
    NSCAssert(saved.value != nil && DPTabIntegrationCacheForPage((id)second).value == nil, @"separate documents do not share cached metadata");
    first.snapshot = nil; DPInvalidateIntegrationPageCache((id)first);
    NSCAssert(saved.value == nil && DPTabIntegrationCacheForPage((id)first).value == nil, @"navigation invalidation cannot show account A while the next document's scope is unknown");
    first.snapshot = good; DPChatGPTSnapshotChanged((id)first);
    first.browser = [NSObject new];
    NSCAssert(DPTabIntegrationCacheForPage((id)first).value == nil, @"moving to a different browser cannot reuse its old cache");
    first.snapshot = good; DPChatGPTSnapshotChanged((id)first); DPTabIntegrationClearCaches(&site);
    NSCAssert(DPTabIntegrationCacheForPage((id)first).value == nil, @"disabling the feature clears every cached document");
    puts("chatgpt-preview-cache: last-good data, status expiry, account isolation and bounded loading passed");
}}
