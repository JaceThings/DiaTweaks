#import "StdPatch/StdPatch.h"

typedef struct DPTabIntegration DPTabIntegration;
@class DPTabIntegrationPreview, DPTabIntegrationPage, DPTabIntegrationContext;

// One static descriptor per patch. URL matches must also pass the exact origin allowlist.
struct DPTabIntegration {
    DPPatch *patch;
    const char *const *origins;
    BOOL (*matchesURL)(NSString *url);  // Optional path filter.
    __unsafe_unretained NSString *scriptKey;  // Folder containing integration.json; nil for native-only previews.
    __unsafe_unretained NSString *scriptNamespace;
    NSUInteger scriptVersion;
    NSTimeInterval refreshInterval, backgroundRefreshInterval, requestTimeout; // Zero uses 0.5s, 2s, 10s.
    void (*snapshotChanged)(DPTabIntegrationPage *page);  // Optional; nil means navigation/disposal, not a temporary read failure.
    DPTabIntegrationPreview *(*makePreview)(DPTabIntegration *integration, id tab);
};
#define DPIntegrationOrigins(...) ((const char *const []){__VA_ARGS__, NULL})
extern const char *const DPTabIntegrationClasses[]; // Shared Dia dependency set for DP_PATCH.classes.

BOOL DPTabIntegrationInstall(DPTabIntegration *integration);
void DPTabIntegrationApply(DPTabIntegration *integration);
void DPTabIntegrationApplyAll(void); // Reapply effective state after a shared parent switch changes.
NSString *DPTabIntegrationVerify(DPTabIntegration *integration);

NSString *DPTabIntegrationURLString(id value);
BOOL DPTabIntegrationAllowsURL(id value, const char *const *origins);
BOOL DPTabIntegrationMatchesURL(DPTabIntegration *integration, id value);
NSString *DPTabIntegrationScript(NSString *key);
NSDictionary *DPTabIntegrationDecode(NSString *value);

@interface DPTabIntegrationPage : NSObject
@property(nonatomic, readonly) DPTabIntegration *integration;
@property(nonatomic, copy, readonly) NSDictionary *snapshot;
@property(nonatomic, readonly) NSTimeInterval receivedAt;
@end
NSArray<DPTabIntegrationPage *> *DPTabIntegrationPages(DPTabIntegration *integration, NSWindow *window);
// Returns nil for no match or duplicate URLs; URL equality cannot identify duplicate tabs safely.
DPTabIntegrationPage *DPTabIntegrationPageForURL(DPTabIntegration *integration, NSWindow *window, id url);
// Also handles a stale scripting URL when only one tab/page exists for that origin in this window.
DPTabIntegrationPage *DPTabIntegrationPageForTab(DPTabIntegration *integration, id tab);
void DPTabIntegrationRead(DPTabIntegrationPage *page);
// Arguments remain JSON data. Commands run only inside this adapter's namespace and origin, then refresh its snapshot.
void DPTabIntegrationCommand(DPTabIntegrationPage *page, NSString *method, NSArray *arguments);

// Memory-only last-good metadata. Nil value/scope means no new observation; a new scope invalidates old data.
// Call invalidate if identity is lost without a replacement scope (for example an adapter's sign-out event).
@interface DPTabIntegrationCache : NSObject
@property(nonatomic, copy, readonly) NSDictionary *value;
@property(nonatomic) NSTimeInterval freshFor, maxAge;  // Defaults: 6 seconds, 1 hour.
- (void)observeValue:(NSDictionary *)value scope:(NSString *)scope receivedAt:(NSTimeInterval)receivedAt;
- (NSDictionary *)valueAtTime:(NSTimeInterval)now;
- (BOOL)isFreshAtTime:(NSTimeInterval)now;
- (void)invalidate;
@end
// Bound to this page's provider and browser; navigation/disposal/disable invalidate it automatically.
DPTabIntegrationCache *DPTabIntegrationCacheForPage(DPTabIntegrationPage *page);
void DPTabIntegrationClearCaches(DPTabIntegration *integration);

// A website-facing view of one tab. Transport objects and callback generations stay private.
// Observation uses the shared scheduler; stopObserving/deallocation cancels only this subscription.
@interface DPTabIntegrationContext : NSObject
@property(nonatomic, readonly) DPTabIntegration *integration;
@property(nonatomic, readonly) DPTabIntegrationPage *page;
@property(nonatomic, readonly) NSDictionary *snapshot;
@property(nonatomic, readonly) DPTabIntegrationCache *cache;
@property(nonatomic, readonly) NSTimeInterval receivedAt;
@property(nonatomic, copy, readonly) NSString *URLString;
@property(nonatomic, copy, readonly) NSDictionary *diagnostics; // Codes/counts/ages only; no page content or URLs.
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab;
- (void)observeChanges:(void (^)(void))changed;
- (void)stopObserving;
- (void)refresh;
- (void)performCommand:(NSString *)method arguments:(NSArray *)arguments;
@end

@interface DPTabIntegrationPreview : NSViewController
@property(nonatomic) DPTabIntegration *integration;
@property(nonatomic, strong) id tab;
@property(nonatomic, copy) void (^sizeChanged)(NSSize);
@property(nonatomic, strong, readonly) DPTabIntegrationContext *context;
@property(nonatomic, readonly) NSTimeInterval startedAt;
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab;
- (void)update; // Called on the main thread by the shared lifecycle; custom layouts override this.
- (void)stop;  // Override to release timers/subscriptions; the host calls this on dismissal.
- (void)navigateToURL:(NSString *)url;  // Selects the exact tab before navigating; dismisses this preview.
@end

NSView *DPTabIntegrationRow(NSString *title, BOOL working, BOOL unread, BOOL pinned,
                          void (^open)(void), void (^pin)(void));
id DPTabIntegrationTabForView(NSView *view);
NSWindow *DPTabIntegrationTabWindow(id tab);
void DPTabIntegrationNavigateTab(DPTabIntegration *integration, id tab, NSString *url);
