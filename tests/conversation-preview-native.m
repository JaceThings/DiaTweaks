#import "TabIntegrations/ConversationPreview.h"
#import "TabIntegrations/Internal.h"

@implementation DPTabIntegrationPage
@end
@interface DPConversationFixtureTab : NSObject
@property(nonatomic, copy) NSString *URL;
@end
@implementation DPConversationFixtureTab
@end
static DPTabIntegrationPage *fixturePage;
static NSUInteger openActions, pinActions;

static const char *const kConversationOrigins[] = {"https://claude.ai", "https://gemini.google.com", "https://t3.chat", NULL};

static NSDictionary *row(id identifier, id title, id url, id activity, id unread) {
    return @{ @"id":identifier ?: NSNull.null, @"title":title ?: NSNull.null,
              @"url":url ?: NSNull.null, @"activity":activity ?: NSNull.null,
              @"unread":unread ?: NSNull.null };
}

static NSDictionary *snapshot(id scope, id status, id recent, id pinned) {
    return @{ @"scopeKey":scope ?: NSNull.null, @"sourceStatus":status ?: NSNull.null,
              @"recent":recent ?: NSNull.null, @"pinned":pinned ?: NSNull.null };
}

// Controlled transport lets the production preview's action model run without navigating a browser.
BOOL DPTabIntegrationEnabled(DPTabIntegration *integration) { return integration != NULL; }
void DPTabIntegrationCommand(DPTabIntegrationPage *page, NSString *method, NSArray *arguments) {
    NSCAssert(page == fixturePage && [method isEqual:@"pin"] && [arguments isEqual:@[@"a"]], @"pin uses the selected context and ID");
    pinActions++;
}
void DPTabIntegrationRead(DPTabIntegrationPage *page) {}
DPTabIntegrationPage *DPTabIntegrationPageForTab(DPTabIntegration *integration, id tab) { return fixturePage; }
void DPTabIntegrationNavigateTab(DPTabIntegration *integration, id tab, NSString *url) {
    NSCAssert([url isEqual:@"https://claude.ai/chat/alpha"], @"open uses the validated row URL");
    openActions++;
}
void DPDismissIntegrationHover(void) {}

int main(void) { @autoreleasepool {
    DPTabIntegration integration = {0};
    integration.origins = kConversationOrigins;
    DPTabIntegrationCache *cache = [DPTabIntegrationCache new];
    NSDictionary *a = row(@"a", @"Alpha", @"https://claude.ai/chat/alpha", @"generating", @YES);
    NSDictionary *b = row(@"b", @"Beta", @"https://gemini.google.com/app/beta", @"idle", @NO);
    NSDictionary *duplicate = row(@"a", @"Duplicate", @"https://t3.chat/chat/a", @"idle", @NO);
    NSDictionary *good = snapshot(@"account:one", @"ready", @[a, b, duplicate], NSNull.null);
    NSDictionary *shown = DPConversationPresentation(cache, good, &integration, 10, 10);
    NSCAssert([shown[@"state"] isEqual:@"live"] && [shown[@"rows"] count] == 2, @"dedupes by identifier and accepts exact provider origins");
    NSCAssert([shown[@"rows"][0][@"activity"] isEqual:@"generating"] && ![shown[@"rows"][0][@"unread"] boolValue], @"working state suppresses an unread dot");

    shown = DPConversationPresentation(cache, nil, &integration, 11, 20);
    NSCAssert([shown[@"state"] isEqual:@"cached"] && [shown[@"rows"] count] == 2, @"missing transport snapshot retains the last scoped value as cached");

    for (NSDictionary *attack in @[
        row(@"../x", @"Bad", @"https://claude.ai/chat/x", @"idle", @NO),
        row(@"foreign", @"Bad", @"https://claude.ai.evil.test/chat/x", @"idle", @NO),
        row(@"credential", @"Bad", @"https://u:p@claude.ai/chat/x", @"idle", @NO),
        row(@"query", @"Bad", @"https://claude.ai/chat/x?next=https://evil.test", @"idle", @NO),
        row(@"fragment", @"Bad", @"https://claude.ai/chat/x#evil", @"idle", @NO),
        row(@"wrong-title", @42, @"https://claude.ai/chat/x", @"idle", @NO),
        row(@"wrong-activity", @"Bad", @"https://claude.ai/chat/x", @42, @NO),
        row(@"wrong-unread", @"Bad", @"https://claude.ai/chat/x", @"idle", @1),
    ]) {
        NSDictionary *bad = snapshot(@"account:one", @"ready", @[attack], NSNull.null);
        shown = DPConversationPresentation(cache, bad, &integration, 11, 11);
        NSCAssert([shown[@"state"] isEqual:@"cached"] && [shown[@"rows"] count] == 2, @"malformed nonempty snapshots preserve good cache as cached rows");
        NSCAssert([shown[@"rows"][0][@"activity"] isEqual:@"unknown"] && ![shown[@"rows"][0][@"unread"] boolValue], @"cached rows suppress live status");
    }
    shown = DPConversationPresentation(cache, snapshot(@"account:one", @"unavailable", @[], NSNull.null), &integration, 20, 20);
    NSCAssert([shown[@"state"] isEqual:@"cached"] && [shown[@"rows"] count] == 2, @"unavailable status preserves cache for the same scope");
    shown = DPConversationPresentation(cache, snapshot(@"account:two", @"unavailable", @[], NSNull.null), &integration, 21, 21);
    NSCAssert([shown[@"state"] isEqual:@"unavailable"] && ![shown[@"rows"] count], @"new scope clears previous account even if unavailable");

    NSDictionary *pinned = row(@"pin", @"Pinned", @"https://t3.chat/chat/pin", @"idle", @NO);
    shown = DPConversationPresentation(cache, snapshot(@"account:three", @"ready", @[a, b], pinned), &integration, 30, 30);
    NSCAssert([shown[@"rows"] count] == 3 && [shown[@"rows"][0][@"id"] isEqual:@"pin"], @"single pinned row leads the recent list");
    shown = DPConversationPresentation(cache, snapshot(@"account:three", @"empty", @[], NSNull.null), &integration, 31, 31);
    NSCAssert([shown[@"state"] isEqual:@"live"] && ![shown[@"rows"] count], @"confirmed empty clears prior rows");
    shown = DPConversationPresentation(cache, snapshot(@"account:three", @"signed-out", @[], NSNull.null), &integration, 32, 32);
    NSCAssert([shown[@"state"] isEqual:@"signedOut"] && ![cache valueAtTime:32], @"sign-out explicitly invalidates cache");

    [cache observeValue:@{@"rows":@[a], @"pin":NSNull.null} scope:@"account:logout" receivedAt:35];
    NSDictionary *malformedLogout = @{@"scopeKey":NSNull.null, @"sourceStatus":@"signed-out", @"recent":@"wrong", @"pinned":@[]};
    shown = DPConversationPresentation(cache, malformedLogout, &integration, 36, 36);
    NSCAssert([shown[@"state"] isEqual:@"signedOut"] && ![cache valueAtTime:36], @"explicit logout invalidates even with a malformed payload envelope");

    DPTabIntegrationCache *expiryCache = [DPTabIntegrationCache new];
    [expiryCache observeValue:@{@"rows":@[a], @"pin":NSNull.null} scope:@"account:expiry" receivedAt:100];
    shown = DPConversationPresentation(expiryCache, nil, &integration, 101, 3701);
    NSCAssert([shown[@"state"] isEqual:@"unavailable"] && ![shown[@"rows"] count], @"expired cached data is removed after max age");

    [cache observeValue:@{@"rows":@[a], @"pin":NSNull.null} scope:@"account:four" receivedAt:40];
    NSDictionary *unscoped = snapshot(NSNull.null, @"ready", @[a], NSNull.null);
    shown = DPConversationPresentation(cache, unscoped, &integration, 41, 41);
    NSCAssert([shown[@"state"] isEqual:@"live"] && [shown[@"rows"] count] == 1 && ![cache valueAtTime:41], @"unscoped valid rows render live without retention");
    shown = DPConversationPresentation(cache, unscoped, &integration, 41, 48);
    NSCAssert([shown[@"state"] isEqual:@"unavailable"] && ![shown[@"rows"] count], @"unscoped rows disappear when their live observation is older than the freshness window");

    shown = DPConversationPresentation(cache, snapshot(@"account:five", @"ready", @[@{@"id":@"bad"}], NSNull.null), &integration, 50, 50);
    NSCAssert([shown[@"state"] isEqual:@"unavailable"] && ![shown[@"rows"] count], @"wrong row field types do not create empty cache data");
    fixturePage = [DPTabIntegrationPage new];
    NSObject *contents = [NSObject new], *browser = [NSObject new];
    fixturePage.contents = contents; fixturePage.browser = browser; fixturePage.integration = &integration;
    fixturePage.receivedAt = NSDate.timeIntervalSinceReferenceDate;
    fixturePage.snapshot = snapshot(@"account:actions", @"ready", @[a], NSNull.null);
    DPConversationFixtureTab *tab = [DPConversationFixtureTab new]; tab.URL = @"https://claude.ai/new";
    DPTabIntegrationConversationPreview *preview = [[DPTabIntegrationConversationPreview alloc] initWithIntegration:&integration tab:tab];
    preview.providerTitle = @"Synthetic provider";
    DPTabIntegrationListContent *content = [preview listContent];
    NSCAssert(content.items.count == 1 && [content.title isEqual:@"Synthetic provider"], @"production preview maps the validated schema to the shared list");
    DPTabIntegrationItem *item = content.items[0];
    item.primaryAction.handler(preview.context, item);
    item.actions[0].handler(preview.context, item);
    NSCAssert(openActions == 1 && pinActions == 1 && item.working && !item.unread, @"production open/pin handlers and status mapping work");
    fixturePage.snapshot = nil;
    content = [preview listContent];
    item = content.items[0];
    NSCAssert([content.state isEqual:@"cached"] && !item.working && !item.unread
        && item.primaryAction.enabledWhenCached && !item.actions[0].enabledWhenCached, @"cached presentation keeps open while disabling pin and live statuses");
    item.primaryAction.handler(preview.context, item);
    item.representedObject = @"https://evil.test/chat/alpha";
    item.primaryAction.handler(preview.context, item);
    NSCAssert(openActions == 2, @"cached open revalidates payload before navigating");
    [preview stop]; fixturePage = nil;
    puts("conversation-preview-native: validation, URL boundaries, cache scopes, status and deduplication passed");
}}
