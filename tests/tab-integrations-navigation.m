#import "TabIntegrations/Backend.h"

@implementation DPTabIntegrationPage
@end
@class DPNavTab, DPNavContents;
@interface DPNavWindow : NSObject
@property(nonatomic, copy) NSString *windowId;
@property(nonatomic, copy) NSArray *appleScriptTabs;
@property(nonatomic, strong) DPNavTab *activeTab;
@end
@implementation DPNavWindow
@end
@interface DPNavNativeWindow : NSObject
@property(nonatomic, copy) NSString *identifier;
@end
@implementation DPNavNativeWindow
@end
@interface DPNavDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, copy) NSArray *appleScriptWindows;
@end
@implementation DPNavDelegate
@end
static NSUInteger metadataWrites, loads, focuses;
static BOOL loadedAfterSelection;
@interface DPNavTab : NSObject
@property(nonatomic, copy) NSString *URL, *tabId;
@property(nonatomic, weak) DPNavWindow *window;
@property(nonatomic) BOOL delayedFocus;
- (instancetype)initWithURL:(NSString *)url;
- (void)focus:(id)sender;
@end
@implementation DPNavTab
- (instancetype)initWithURL:(NSString *)url { if ((self = [super init])) _URL = [url copy]; return self; }
// Dia's scripting URL setter was observed to return without navigating the web contents.
- (void)setURL:(NSString *)url { (void)_URL; metadataWrites++; }
- (void)focus:(id)sender {
    focuses++;
    if (!self.delayedFocus) self.window.activeTab = self;
    else dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        self.window.activeTab = self;
    });
}
@end
@interface DPNavController : NSObject
@property(nonatomic, weak) DPNavContents *contents;
@property(nonatomic, weak) DPNavWindow *window;
@property(nonatomic, weak) DPNavTab *target;
- (id)load:(NSURL *)url initiatorOrigin:(NSURL *)origin;
@end
@interface DPNavContents : NSObject
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) id navigationController;
@end
@implementation DPNavContents
@end
@implementation DPNavController
- (id)load:(NSURL *)url initiatorOrigin:(NSURL *)origin {
    NSCAssert([url isKindOfClass:NSURL.class] && !origin, @"native controller receives a URL and no fabricated initiator");
    loads++;
    loadedAfterSelection = self.window.activeTab == self.target;
    self.contents.url = url;
    return [NSObject new];
}
@end
static DPTabIntegration site;
static DPTabIntegrationPage *page;
static DPNavNativeWindow *native;
static DPNavTab *target;
static BOOL pageAvailable = YES;
BOOL DPTabIntegrationEnabled(DPTabIntegration *value) { return value && value->patch->on; }
DPTabIntegration *DPTabIntegrationForURL(id url) { return DPTabIntegrationEnabled(&site) && DPTabIntegrationMatchesURL(&site, url) ? &site : NULL; }
NSWindow *DPTabIntegrationTabWindow(id tab) { return tab == target ? (id)native : nil; }
DPTabIntegrationPage *DPTabIntegrationPageForTab(DPTabIntegration *value, id tab) { return pageAvailable && value == &site && tab == target ? page : nil; }
static void pump(NSTimeInterval duration) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:duration];
    while (until.timeIntervalSinceNow > 0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
}
static BOOL require(BOOL condition, NSString *message) {
    if (!condition) fprintf(stderr, "navigation regression: %s\n", message.UTF8String);
    return condition;
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    DPPatch patch = {.key=@"navigationFixture", .on=YES};
    site = (DPTabIntegration){.patch=&patch, .origins=DPIntegrationOrigins("https://example.com")};
    DPNavDelegate *delegate = [DPNavDelegate new];
    DPNavWindow *window = [DPNavWindow new]; window.windowId = @"window-a";
    DPNavWindow *otherWindow = [DPNavWindow new]; otherWindow.windowId = @"window-b";
    delegate.appleScriptWindows = @[otherWindow, window]; NSApp.delegate = delegate;
    native = [DPNavNativeWindow new]; native.identifier = window.windowId;
    target = [[DPNavTab alloc] initWithURL:@"https://example.com/"]; target.tabId = @"target"; target.window = window;
    DPNavTab *other = [[DPNavTab alloc] initWithURL:@"https://other.example/"]; other.tabId = @"other"; other.window = window;
    DPNavTab *sameURLInOtherWindow = [[DPNavTab alloc] initWithURL:@"https://example.com/"];
    sameURLInOtherWindow.tabId = @"unrelated"; sameURLInOtherWindow.window = otherWindow;
    otherWindow.appleScriptTabs = @[sameURLInOtherWindow]; otherWindow.activeTab = sameURLInOtherWindow;
    window.appleScriptTabs = @[other, target]; window.activeTab = other;
    DPNavContents *contents = [DPNavContents new]; contents.url = [NSURL URLWithString:@"https://example.com/chat/old"];
    DPNavController *controller = [DPNavController new]; controller.contents = contents; controller.window = window; controller.target = target;
    contents.navigationController = controller;
    page = [DPTabIntegrationPage new]; page.contents = contents; page.browser = delegate; page.integration = &site;

    DPTabIntegrationNavigateTab(&site, target, @"https://example.com/chat/new"); pump(0.2);
    if (!require(loads == 1 && loadedAfterSelection && [contents.url.path isEqual:@"/chat/new"], @"focusing a tab must load the selected conversation in its real web contents")) return 1;
    if (!require(metadataWrites == 0 && [target.URL isEqual:@"https://example.com/"], @"navigation must not depend on Dia's stale scripting URL setter")) return 1;
    if (!require(otherWindow.activeTab == sameURLInOtherWindow, @"a matching URL in another window is not a navigation target")) return 1;

    target.delayedFocus = YES; window.activeTab = other;
    DPTabIntegrationNavigateTab(&site, target, @"https://example.com/chat/delayed"); pump(0.25);
    if (!require(loads == 2 && loadedAfterSelection && [contents.url.path isEqual:@"/chat/delayed"], @"deferred selection completes before native loading")) return 1;
    target.delayedFocus = NO;
    NSUInteger previousLoads = loads, previousFocuses = focuses;
    DPTabIntegrationNavigateTab(&site, target, @"https://evil.example/chat/wrong"); pump(0.1);
    if (!require(loads == previousLoads && focuses == previousFocuses, @"foreign destinations cannot focus or navigate")) return 1;
    contents.url = [NSURL URLWithString:@"https://other.example/changed"];
    DPTabIntegrationNavigateTab(&site, target, @"https://example.com/chat/new"); pump(0.1);
    if (!require(loads == previousLoads, @"a stale scripting URL cannot hijack contents now on another origin")) return 1;
    contents.url = [NSURL URLWithString:@"https://example.com/chat/old"];
    contents.navigationController = [NSObject new];
    DPTabIntegrationNavigateTab(&site, target, @"https://example.com/chat/new"); pump(0.1);
    if (!require(loads == previousLoads && metadataWrites == 0, @"missing native navigation fails closed without the inert setter")) return 1;
    contents.navigationController = controller; pageAvailable = NO;
    DPTabIntegrationNavigateTab(&site, target, @"https://example.com/chat/new"); pump(0.1);
    if (!require(loads == previousLoads, @"an unresolved or ambiguous backing page cannot be navigated")) return 1;
    pageAvailable = YES;
    DPTabIntegrationNavigateTab(&site, target, @"https://example.com/chat/new"); patch.on = NO; pump(0.1);
    if (!require(loads == previousLoads, @"disable cancels a queued navigation")) return 1;
    NSApp.delegate = nil;
    puts("tab-integrations-navigation: native conversation loads, deferred focus, stale scripting metadata and routing guards passed");
}}
