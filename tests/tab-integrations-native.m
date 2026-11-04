#import "TabIntegrations/Internal.h"
#import "TabIntegrations/PageHooks.h"
#import <objc/message.h>

// Stand-in transport only: registry, page selection, script generation and callback guards use production code.
@interface DPFixtureContents : NSObject
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) NSMutableArray<NSString *> *scripts;
@property(nonatomic, strong) NSMutableArray *callbacks;
- (void)complete:(NSDictionary *)value;
@end
@implementation DPFixtureContents
- (instancetype)init { if ((self = [super init])) { _scripts = [NSMutableArray new]; _callbacks = [NSMutableArray new]; } return self; }
- (void)executeJavascript:(NSString *)script completion:(void (^)(NSString *, BOOL))completion {
    [self.scripts addObject:script]; [self.callbacks addObject:[completion copy]];
}
- (void)complete:(NSDictionary *)value {
    NSCAssert(self.callbacks.count, @"transport has a pending request");
    void (^callback)(NSString *, BOOL) = self.callbacks.firstObject;
    [self.callbacks removeObjectAtIndex:0];
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    callback([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], YES);
}
@end

BOOL DPIntegrationHostAvailable(void) { return YES; }
void DPInstallIntegrationHover(void) {}
void DPApplyIntegrationHover(void) {}
NSString *DPVerifyIntegrationHover(DPTabIntegration *site) { return nil; }
void DPHook(const char *name, SEL selector, IMP implementation) {}
IMP DPOriginalIMP(id object, SEL selector, IMP replacement) { return NULL; }
void DPOnLaunch(void (^block)(void)) {}
NSString *DPTabIntegrationScript(NSString *key) {
    if ([key isEqual:@"FixtureA"]) return @"window['Fixture-A\\\"']={version:1,snapshot(){return {loaded:'A'}},pin(value){window.lastPin=value},dispose(){window.disposed='A'}}";
    if ([key isEqual:@"FixtureB"]) return @"window.FixtureB={version:1,snapshot(){return {loaded:'B'}},dispose(){window.disposed='B'}}";
    return nil;
}
static DPTabIntegrationPreview *preview(DPTabIntegration *site, id tab) { return nil; }
static NSUInteger snapshotsReceived, pagesDisposed;
static void changed(DPTabIntegrationPage *page) { if (page.snapshot) snapshotsReceived++; else pagesDisposed++; }
static void noop(id self, SEL cmd) {}
static void backendClass(const char *name, Class parent, NSArray<NSString *> *selectors) {
    Class cls = objc_allocateClassPair(parent, name, 0);
    for (NSString *selector in selectors) class_addMethod(cls, NSSelectorFromString(selector), (IMP)noop, "v@:");
    objc_registerClassPair(cls);
}
static void drain(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.015]]; }
static void complete(DPFixtureContents *contents, NSDictionary *value) { [contents complete:value]; drain(); }

@interface DPFixtureWindow : NSObject
@property(nonatomic, copy) NSArray *tabs;
@end
@implementation DPFixtureWindow
@end
@interface DPFixtureTab : NSObject
@property(nonatomic, copy) NSString *URL, *tabId;
@property(nonatomic, weak) DPFixtureWindow *fixtureWindow;
@end
@implementation DPFixtureTab
@end
NSWindow *DPTabIntegrationTabWindow(id tab) { return (NSWindow *)[tab fixtureWindow]; }
NSArray *DPIntegrationTabsInWindow(NSWindow *window) { return [(DPFixtureWindow *)window tabs]; }

int main(void) { @autoreleasepool {
    backendClass("ArcWebContents", DPFixtureContents.class, @[]);
    backendClass(DPDiaBrowser, NSObject.class, @[@"createWebContents:", @"setWindow:", @"takeOwnershipOfWebContents:"]);
    backendClass(DPDiaBrowserDelegate, NSObject.class, @[@"browser:didRestoreWebContents:withSessionId:", @"browser:didCreateNewWebContents:isActive:"]);
    DPPatch patchA = {.key=@"fixtureA", .on=YES}, patchB = {.key=@"fixtureB", .on=YES};
    DPTabIntegration a = {.patch=&patchA, .origins=DPIntegrationOrigins("https://a.example"), .scriptKey=@"FixtureA", .scriptNamespace=@"Fixture-A\"", .scriptVersion=1, .snapshotChanged=changed, .makePreview=preview};
    DPTabIntegration b = {.patch=&patchB, .origins=DPIntegrationOrigins("https://b.example"), .scriptKey=@"FixtureB", .scriptNamespace=@"FixtureB", .scriptVersion=1, .makePreview=preview};
    NSCAssert(DPTabIntegrationInstall(&a) && DPTabIntegrationInstall(&b), @"two providers install independently");
    NSCAssert(DPTabIntegrationForURL(@"https://a.example/c/1") == &a && DPTabIntegrationForURL(@"https://b.example/") == &b, @"registry routes by origin");
    for (NSString *url in @[@"http://a.example/", @"https://user:pass@a.example/", @"https://a.example.evil/", @"https://a.example:444/"])
        NSCAssert(!DPTabIntegrationMatchesURL(&a, url), @"origin policy rejects lookalikes and credentials");
    NSCAssert(DPTabIntegrationMatchesURL(&a, @"https://a.example:443/"), @"default HTTPS port is canonical");
    NSCAssert(DPTabIntegrationAllowsURL(@"https://[::1]:8443/path", DPIntegrationOrigins("https://[::1]:8443")), @"IPv6 origins match exactly");
    DPPatch badPatch = {.key=@"badOrigin", .on=YES};
    DPTabIntegration bad = {.patch=&badPatch, .origins=DPIntegrationOrigins("https://a.example", "https://a.example/not-an-origin"), .makePreview=preview};
    NSCAssert(!DPTabIntegrationInstall(&bad) && badPatch.unavailable && !badPatch.on, @"every origin entry must be valid");

    NSObject *browser = [NSObject new];
    DPFixtureContents *ca = [DPFixtureContents new], *cb = [DPFixtureContents new];
    ca.url = [NSURL URLWithString:@"https://a.example/c/1"]; cb.url = [NSURL URLWithString:@"https://b.example/"];
    DPRememberIntegrationPage(ca, browser); DPRememberIntegrationPage(cb, browser);
    DPTabIntegrationPage *pa = DPTabIntegrationPages(&a, nil).firstObject, *pb = DPTabIntegrationPages(&b, nil).firstObject;
    DPFixtureWindow *window = [DPFixtureWindow new], *otherWindow = [DPFixtureWindow new];
    DPIntegrationSetBrowserWindow(browser, (NSWindow *)window);
    DPFixtureTab *tab = [DPFixtureTab new], *sibling = [DPFixtureTab new];
    tab.tabId = @"tab-a"; tab.URL = @"https://a.example/"; tab.fixtureWindow = window;
    window.tabs = @[tab];
    NSCAssert(DPTabIntegrationPageForTab(&a, tab) == pa, @"one tab/page resolves despite stale scripting homepage URL");
    sibling.tabId = @"tab-b"; sibling.URL = @"https://a.example/c/2"; sibling.fixtureWindow = window;
    window.tabs = @[tab, sibling];
    NSCAssert(!DPTabIntegrationPageForTab(&a, tab), @"multiple site tabs prevent a stale-URL guess");
    tab.URL = ca.url.absoluteString;
    NSCAssert(DPTabIntegrationPageForTab(&a, tab) == pa, @"unique exact page remains selectable with other tabs");
    sibling.URL = tab.URL;
    NSCAssert(!DPTabIntegrationPageForTab(&a, tab), @"duplicate scripting URLs cannot claim one arbitrary page");
    window.tabs = @[tab]; otherWindow.tabs = @[tab]; tab.fixtureWindow = otherWindow;
    NSCAssert(!DPTabIntegrationPageForTab(&a, tab), @"another window cannot claim this browser's data");
    tab.fixtureWindow = window;
    NSCAssert(DPTabIntegrationPageForURL(&a, nil, ca.url) == pa, @"a unique matching URL resolves its page");
    DPFixtureContents *duplicate = [DPFixtureContents new]; duplicate.url = ca.url;
    DPRememberIntegrationPage(duplicate, browser);
    NSCAssert(!DPTabIntegrationPageForTab(&a, tab), @"multiple same-origin pages remain ambiguous");
    NSCAssert(!DPTabIntegrationPageForURL(&a, nil, ca.url), @"duplicate URLs never select an arbitrary document");
    duplicate.url = [NSURL URLWithString:@"https://elsewhere.example/"]; DPRememberIntegrationPage(duplicate, browser);
    NSCAssert(DPTabIntegrationPageForURL(&a, nil, ca.url) == pa, @"removing ambiguity restores the unique document");
    DPTabIntegrationRead(pa); complete(ca, @{@"owner":@"A"});
    NSCAssert(snapshotsReceived == 1, @"adapter can cache success before any hover exists");
    DPTabIntegrationCache *cached = DPTabIntegrationCacheForPage(pa);
    [cached observeValue:@{@"owner":@"A"} scope:@"scope-a" receivedAt:NSDate.timeIntervalSinceReferenceDate];
    NSUInteger disposedBeforeNavigation = pagesDisposed;
    ca.url = [NSURL URLWithString:@"https://a.example/c/other"];
    DPRememberIntegrationPage(ca, browser);
    NSCAssert(!cached.value && !pa.snapshot && pagesDisposed == disposedBeforeNavigation + 1, @"production same-origin navigation invalidates the public cache and notifies the adapter");
    ca.url = [NSURL URLWithString:@"https://a.example/c/1"]; DPRememberIntegrationPage(ca, browser);
    DPTabIntegrationRead(pa); complete(ca, @{@"owner":@"A"});
    DPTabIntegrationRead(pb); complete(cb, @{@"owner":@"B"});
    NSCAssert([pa.snapshot[@"owner"] isEqual:@"A"] && [pb.snapshot[@"owner"] isEqual:@"B"], @"snapshots are provider-local");
    DPTabIntegrationRead(pa); complete(ca, @{@"installNeeded":@[]});
    NSCAssert([pa.snapshot[@"installNeeded"] isKindOfClass:NSArray.class], @"metadata cannot crash the install-needed check");
    patchA.on = NO; DPTabIntegrationApply(&a);
    NSCAssert(pagesDisposed > 0, @"provider disposal notifies its adapter to discard cached metadata");
    NSCAssert(!pa.snapshot && DPTabIntegrationPages(&a, nil).count == 0, @"disable disposes that provider");
    NSCAssert([pb.snapshot[@"owner"] isEqual:@"B"] && DPTabIntegrationPages(&b, nil).count == 1, @"disable leaves the other provider intact");
    patchB.on = NO; DPTabIntegrationApply(&b);
    [ca.callbacks removeAllObjects]; [cb.callbacks removeAllObjects];

    patchA.on = YES; DPRememberIntegrationPage(ca, browser);
    pa = DPTabIntegrationPages(&a, nil).firstObject;
    DPTabIntegrationRead(pa);
    NSString *poll = ca.scripts.lastObject;
    complete(ca, @{@"installNeeded":@YES});
    NSString *install = ca.scripts.lastObject;
    complete(ca, @{@"loaded":@"A"});
    NSString *payload = @"x'); globalThis.injected=true;//\nline two";
    DPTabIntegrationCommand(pa, @"pin", @[payload]);
    NSString *command = ca.scripts.lastObject;
    complete(ca, @{@"command":@YES});
    NSCAssert([pa.snapshot[@"command"] boolValue], @"commands refresh their own snapshot");

    DPTabIntegrationRead(pa);
    ca.url = [NSURL URLWithString:@"https://b.example/"];
    DPRememberIntegrationPage(ca, browser);
    complete(ca, @{@"owner":@"late A"});
    NSCAssert(!pa.snapshot && DPTabIntegrationPages(&a, nil).count == 0, @"late result after navigation cannot populate the old provider");
    [ca.callbacks removeAllObjects];
    ca.url = [NSURL URLWithString:@"https://a.example/c/1"]; DPRememberIntegrationPage(ca, browser);
    pa = DPTabIntegrationPages(&a, nil).firstObject;
    DPTabIntegrationCommand(pa, @"pin", @[@"test"]);
    patchA.on = NO;
    complete(ca, @{@"owner":@"disabled callback"});
    NSCAssert(!pa.snapshot, @"late command after disable cannot restore a snapshot");
    DPDisposeIntegrationPage(pa);
    NSString *dispose = ca.scripts.lastObject;

    DPPatch collisionPatch = {.key=@"collision", .on=YES};
    DPTabIntegration collision = {.patch=&collisionPatch, .origins=DPIntegrationOrigins("https://a.example"), .makePreview=preview};
    NSCAssert(DPTabIntegrationInstall(&collision), @"a native-only provider does not require a script");
    patchA.on = YES;
    NSCAssert(!DPTabIntegrationForURL(@"https://a.example/"), @"ambiguous providers fail closed");
    collisionPatch.on = NO;
    NSCAssert(DPTabIntegrationForURL(@"https://a.example/") == &a, @"disabling the conflicting provider restores routing");
    DPFixtureContents *timed = [DPFixtureContents new]; timed.url = [NSURL URLWithString:@"https://a.example/timeouts"];
    DPRememberIntegrationPage(timed, browser);
    DPTabIntegrationPage *pending = DPTabIntegrationPageForURL(&a, nil, timed.url);
    NSCAssert(DPIntegrationRefreshDelay(pending) == 2, @"background providers use the shared default schedule");
    a.backgroundRefreshInterval = 120;
    pending.failureCount = 4;
    NSCAssert(DPIntegrationRefreshDelay(pending) == 120, @"retry backoff never makes a deliberately slow provider faster");
    a.backgroundRefreshInterval = 0; pending.failureCount = 0;
    DPTabIntegrationRead(pending);
    pending.requestedAt -= 100;
    DPTabIntegrationRead(pending);
    NSCAssert([pending.lastFailure isEqual:@"timeout"] && pending.failureCount == 1, @"hung transport records a retryable timeout");
    complete(timed, @{@"stale":@YES});
    NSCAssert(!pending.snapshot && pending.inFlight, @"a timed-out callback cannot clear or populate the replacement request");
    complete(timed, @{@"tracking":@{@"phase":@"delivered"}});
    NSCAssert([pending.diagnosticCode isEqual:@"ready"] && pending.failureCount == 0, @"successful retry restores arbitrary provider data");
    DPTabIntegrationRead(pending);
    void (^malformed)(NSString *, BOOL) = timed.callbacks.firstObject;
    [timed.callbacks removeObjectAtIndex:0]; malformed(@"not JSON", YES); drain();
    NSCAssert([pending.lastFailure isEqual:@"read-failed"] && pending.snapshot[@"tracking"], @"read failure retains last metadata with explicit diagnostics");
    DPTabIntegrationRead(pending);
    NSObject *replacementBrowser = [NSObject new];
    DPRememberIntegrationPage(timed, replacementBrowser);
    complete(timed, @{@"fromOldBrowser":@YES});
    NSCAssert(!pending.snapshot, @"ownership changes invalidate callbacks as well as cache");
    patchA.on = patchB.on = NO; DPTabIntegrationApply(&a);
    NSDictionary *scripts = @{@"poll":poll, @"install":install, @"command":command, @"dispose":dispose, @"payload":payload};
    [[NSJSONSerialization dataWithJSONObject:scripts options:0 error:nil] writeToFile:@"build/integration-protocol-scripts.json" atomically:YES];
    puts("tab-integrations-native: routing, isolation, lifecycle and stale callbacks passed");
}}
