#import "TabIntegrations/Internal.h"

@interface DPCachePage : NSObject
@property(nonatomic, strong) id contents, browser;
@property(nonatomic) DPTabIntegration *integration;
@end
@implementation DPCachePage
@end
int main(void) { @autoreleasepool {
    DPTabIntegrationCache *cache = [DPTabIntegrationCache new];
    NSDictionary *data = @{@"items":@[@{@"label":@"Another website", @"path":@"/inbox/1"}]};
    [cache observeValue:data scope:@"profile-a" receivedAt:100];
    NSCAssert([[cache valueAtTime:100] isEqual:data] && [cache isFreshAtTime:100], @"public cache accepts any adapter's metadata schema");
    [cache observeValue:nil scope:@"profile-a" receivedAt:102];
    NSCAssert([[cache valueAtTime:102] isEqual:data] && ![cache isFreshAtTime:102], @"temporary failure preserves values and exposes stale status");
    [cache observeValue:nil scope:nil receivedAt:103];
    NSCAssert([[cache valueAtTime:103] isEqual:data] && ![cache isFreshAtTime:103], @"a failed scope observation does not invent a new identity");
    [cache invalidate];
    NSCAssert(![cache valueAtTime:103], @"adapters can explicitly invalidate when identity is lost");
    [cache observeValue:data scope:@"profile-a" receivedAt:110];
    NSCAssert(![cache isFreshAtTime:117], @"stale age is independent of website statuses");
    cache.freshFor = 20; cache.maxAge = 30;
    NSCAssert([cache isFreshAtTime:117] && ![cache valueAtTime:141], @"other sites can choose freshness and expiry bounds");
    [cache observeValue:data scope:@"profile-a" receivedAt:200];
    [cache observeValue:nil scope:@"profile-b" receivedAt:201];
    NSCAssert(![cache valueAtTime:201], @"a new scope invalidates old metadata even when the new fetch fails");
    DPTabIntegration a = {0}, b = {0};
    DPCachePage *pa = [DPCachePage new], *pb = [DPCachePage new];
    pa.contents = [NSObject new]; pa.browser = [NSObject new]; pa.integration = &a;
    pb.contents = [NSObject new]; pb.browser = pa.browser; pb.integration = &b;
    DPTabIntegrationCache *ca = DPTabIntegrationCacheForPage((id)pa), *cb = DPTabIntegrationCacheForPage((id)pb);
    [ca observeValue:data scope:@"same-scope" receivedAt:300]; [cb observeValue:data scope:@"same-scope" receivedAt:300];
    DPTabIntegrationClearCaches(&a);
    NSCAssert(![ca valueAtTime:301] && [cb valueAtTime:301], @"disabling one provider preserves another's cache");
    pb.browser = [NSObject new];
    NSCAssert(DPTabIntegrationCacheForPage((id)pb).value == nil && cb.value == nil, @"browser changes invalidate rather than share cache");
    DPTabIntegrationCache *moved = DPTabIntegrationCacheForPage((id)pb);
    [moved observeValue:data scope:@"same-scope" receivedAt:400];
    pb.integration = &a;
    NSCAssert(DPTabIntegrationCacheForPage((id)pb).value == nil && moved.value == nil, @"provider changes cannot reuse another adapter's metadata");
    puts("tab-integrations-cache: reusable schema, expiry, scopes and provider/browser isolation passed");
}}
