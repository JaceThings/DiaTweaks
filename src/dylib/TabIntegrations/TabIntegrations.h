#import "StdPatch/StdPatch.h"

typedef struct DPTabIntegration DPTabIntegration;
@class DPTabIntegrationPreview, DPTabIntegrationPage;

// One static descriptor per patch. URL matches must also pass the exact origin allowlist.
struct DPTabIntegration {
    DPPatch *patch;
    const char *const *origins;
    BOOL (*matchesURL)(NSString *url);  // Optional path filter.
    __unsafe_unretained NSString *scriptKey;  // Folder containing integration.json; nil for native-only previews.
    __unsafe_unretained NSString *scriptNamespace;
    NSUInteger scriptVersion;
    void (*snapshotChanged)(DPTabIntegrationPage *page);  // Optional; nil means navigation/disposal, not a temporary read failure.
    DPTabIntegrationPreview *(*makePreview)(DPTabIntegration *integration, id tab);
};
#define DPIntegrationOrigins(...) ((const char *const []){__VA_ARGS__, NULL})

BOOL DPTabIntegrationInstall(DPTabIntegration *integration);
void DPTabIntegrationApply(DPTabIntegration *integration);
NSString *DPTabIntegrationVerify(DPTabIntegration *integration);

NSString *DPTabIntegrationURLString(id value);
BOOL DPTabIntegrationAllowsURL(id value, const char *const *origins);
BOOL DPTabIntegrationMatchesURL(DPTabIntegration *integration, id value);
NSString *DPTabIntegrationScript(NSString *key);
NSDictionary *DPTabIntegrationDecode(NSString *value);

@interface DPTabIntegrationPage : NSObject
@property(nonatomic) DPTabIntegration *integration;
@property(nonatomic, weak) id contents, browser;
@property(nonatomic, copy) NSDictionary *snapshot;
@property(nonatomic) BOOL inFlight;
@property(nonatomic) NSTimeInterval receivedAt, requestedAt;
@property(nonatomic) NSUInteger generation;
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

@interface DPTabIntegrationPreview : NSViewController
@property(nonatomic) DPTabIntegration *integration;
@property(nonatomic, strong) id tab;
@property(nonatomic, copy) void (^sizeChanged)(NSSize);
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab;
- (void)stop;  // Override to release timers/subscriptions; the host calls this on dismissal.
- (void)navigateToURL:(NSString *)url;  // Selects the exact tab before navigating; dismisses this preview.
@end

NSView *DPTabIntegrationRow(NSString *title, BOOL working, BOOL unread, BOOL pinned,
                          void (^open)(void), void (^pin)(void));
id DPTabIntegrationTabForView(NSView *view);
NSWindow *DPTabIntegrationTabWindow(id tab);
void DPTabIntegrationNavigateTab(DPTabIntegration *integration, id tab, NSString *url);
