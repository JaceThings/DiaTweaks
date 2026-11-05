#import "Internal.h"

@interface DPTabIntegrationCache ()
@property(nonatomic, copy) NSDictionary *value;
@property(nonatomic, copy) NSString *scope;
@property(nonatomic, weak) id browser;
@property(nonatomic) DPTabIntegration *integration;
@property(nonatomic) NSTimeInterval receivedAt;
@property(nonatomic) BOOL sourceAvailable;
@end
static NSMapTable<DPTabIntegrationPage *, DPTabIntegrationCache *> *DPCaches;

@implementation DPTabIntegrationCache
- (instancetype)init { if ((self = [super init])) { _freshFor = 6; _maxAge = 3600; } return self; }
- (void)observeValue:(NSDictionary *)value scope:(NSString *)scope receivedAt:(NSTimeInterval)receivedAt {
    BOOL knownScope = [scope isKindOfClass:NSString.class] && scope.length > 0 && scope.length <= 512;
    if (knownScope && ![scope isEqual:self.scope]) { [self invalidate]; self.scope = scope; }
    self.sourceAvailable = knownScope && [value isKindOfClass:NSDictionary.class];
    if (self.sourceAvailable) { self.value = value; self.receivedAt = receivedAt; }
}
- (NSDictionary *)valueAtTime:(NSTimeInterval)now {
    if (self.value && now - self.receivedAt > self.maxAge) [self invalidate];
    return self.value;
}
- (BOOL)isFreshAtTime:(NSTimeInterval)now {
    return [self valueAtTime:now] && self.sourceAvailable && now - self.receivedAt <= self.freshFor;
}
- (void)invalidate { self.value = nil; self.scope = nil; self.sourceAvailable = NO; }
@end

DPTabIntegrationCache *DPTabIntegrationCacheForPage(DPTabIntegrationPage *page) {
    if (!page || !page.contents || !page.browser || !page.integration) return nil;
    if (!DPCaches) DPCaches = [NSMapTable weakToStrongObjectsMapTable];
    DPTabIntegrationCache *cache = [DPCaches objectForKey:page];
    if (!cache || cache.browser != page.browser || cache.integration != page.integration) {
        [cache invalidate];
        cache = [DPTabIntegrationCache new];
        cache.browser = page.browser;
        cache.integration = page.integration;
        [DPCaches setObject:cache forKey:page];
    }
    return cache;
}
void DPInvalidateIntegrationPageCache(DPTabIntegrationPage *page) {
    [[DPCaches objectForKey:page] invalidate];
    [DPCaches removeObjectForKey:page];
}
void DPTabIntegrationClearCaches(DPTabIntegration *integration) {
    for (DPTabIntegrationPage *page in DPCaches.keyEnumerator.allObjects)
        if ([DPCaches objectForKey:page].integration == integration) DPInvalidateIntegrationPageCache(page);
}
