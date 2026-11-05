#import "Backend.h"
#import "Scheduler.h"

static NSHashTable<DPTabIntegrationContext *> *DPObservedContexts;
@interface DPTabIntegrationContext ()
@property(nonatomic) DPTabIntegration *integration;
@property(nonatomic, strong) id tab;
@property(nonatomic, strong) DPIntegrationSubscription *subscription;
@property(nonatomic, copy) void (^changed)(void);
@end
@implementation DPTabIntegrationContext
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab {
    if ((self = [super init])) { _integration = integration; _tab = tab; }
    return self;
}
- (DPTabIntegrationPage *)page { return DPTabIntegrationPageForTab(self.integration, self.tab); }
- (NSDictionary *)snapshot { return self.page.snapshot; }
- (DPTabIntegrationCache *)cache { return DPTabIntegrationCacheForPage(self.page); }
- (NSTimeInterval)receivedAt { return self.page.receivedAt; }
- (NSString *)URLString { return DPIntegrationTabURL(self.tab); }
- (NSDictionary *)diagnostics {
    if (!DPTabIntegrationEnabled(self.integration)) return @{@"code":@"disabled"};
    return DPIntegrationDiagnostics(self.page, NSDate.timeIntervalSinceReferenceDate);
}
- (void)observeChanges:(void (^)(void))changed {
    [self stopObserving];
    if (!changed) return;
    if (!DPObservedContexts) DPObservedContexts = [NSHashTable weakObjectsHashTable];
    [DPObservedContexts addObject:self];
    self.changed = changed;
    __weak DPTabIntegrationContext *weak = self;
    self.subscription = DPIntegrationSchedule(^(NSTimeInterval now) { if (weak.changed) weak.changed(); });
    [self refresh];
    if (self.changed) self.changed();
}
- (void)stopObserving {
    [self.subscription cancel]; self.subscription = nil;
    [DPObservedContexts removeObject:self]; self.changed = nil;
}
- (void)refresh { DPTabIntegrationRead(self.page); }
- (void)performCommand:(NSString *)method arguments:(NSArray *)arguments {
    DPTabIntegrationCommand(self.page, method, arguments);
}
- (void)dealloc { [self stopObserving]; }
@end
BOOL DPIntegrationPageIsObserved(DPTabIntegrationPage *page) {
    for (DPTabIntegrationContext *context in DPObservedContexts.allObjects)
        if (context.page == page) return YES;
    return NO;
}
NSDictionary *DPIntegrationDiagnostics(DPTabIntegrationPage *page, NSTimeInterval now) {
    if (!page) return @{@"code":@"no-matching-page"};
    DPTabIntegrationCache *cache = DPTabIntegrationCacheForPage(page);
    BOOL available = [cache valueAtTime:now] != nil;
    return @{@"code":page.diagnosticCode ?: @"not-requested", @"reading":@(page.inFlight),
        @"lastFailure":page.lastFailure ?: @"", @"failures":@(page.failureCount),
        @"cache":available ? ([cache isFreshAtTime:now] ? @"fresh" : @"cached") : @"missing",
        @"lastSuccessAge":page.receivedAt > 0 ? @(MAX(0, now - page.receivedAt)) : NSNull.null};
}
