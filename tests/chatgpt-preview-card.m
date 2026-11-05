#import "Patches/ChatGPTPreview/ChatGPTPreview.h"
#import "TabIntegrations/Internal.h"

@interface DPCardFixtureTab : NSObject
@property(nonatomic, copy) NSString *URL;
@end
@implementation DPCardFixtureTab
@end
@implementation DPTabIntegrationPage
@end
static DPTabIntegrationPage *page;
static NSUInteger navigated, pinned;
BOOL DPTabIntegrationEnabled(DPTabIntegration *site) { return site && site->patch->on; }
DPTabIntegrationPage *DPTabIntegrationPageForTab(DPTabIntegration *site, id tab) { return DPTabIntegrationEnabled(site) ? page : nil; }
void DPTabIntegrationRead(DPTabIntegrationPage *value) {}
void DPTabIntegrationCommand(DPTabIntegrationPage *value, NSString *method, NSArray *arguments) {
    NSCAssert(value == page && [method isEqual:@"pin"] && arguments.count == 1, @"pin commands use the selected context");
    pinned++;
}
void DPTabIntegrationNavigateTab(DPTabIntegration *site, id tab, NSString *url) {
    NSCAssert([url isEqual:@"https://chatgpt.com/c/a"], @"a conversation opens through shared exact-tab navigation");
    navigated++;
}
void DPDismissIntegrationHover(void) {}
static NSArray<NSView *> *rows(NSView *view) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSView *row, NSDictionary *_) {
        return row.frame.size.width == 256 && row.frame.size.height == 36;
    }];
    return [view.subviews filteredArrayUsingPredicate:predicate];
}
static NSButton *pinButton(NSView *row) {
    for (NSView *child in row.subviews) if ([child isKindOfClass:NSButton.class]) return (NSButton *)child;
    return nil;
}
@interface DPTimedOutCard : DPChatGPTCard
@end
@implementation DPTimedOutCard
- (NSTimeInterval)startedAt { return NSDate.timeIntervalSinceReferenceDate - 7; }
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    DPPatch patch = {.key=@"cardFixture", .on=YES};
    DPTabIntegration site = {.patch=&patch, .origins=DPIntegrationOrigins("https://chatgpt.com")};
    DPCardFixtureTab *tab = [DPCardFixtureTab new]; tab.URL = @"https://chatgpt.com/c/a";
    NSObject *contents = [NSObject new], *browser = [NSObject new];
    page = [DPTabIntegrationPage new]; page.integration = &site; page.contents = contents; page.browser = browser;
    page.receivedAt = NSDate.timeIntervalSinceReferenceDate;
    page.snapshot = @{@"scopeKey":@"account:fixture", @"sourceLoaded":@YES, @"sourceStatus":@"ready",
        @"recent":@[@{@"id":@"a", @"title":@"Synthetic working chat", @"activity":@"generating"},
                    @{@"id":@"b", @"title":@"Synthetic unread chat", @"unread":@YES}], @"pinned":NSNull.null};
    DPChatGPTCard *card = [[DPChatGPTCard alloc] initWithIntegration:&site tab:tab];
    (void)card.view; [card update];
    NSArray *fresh = rows(card.view);
    NSCAssert(fresh.count == 2 && card.preferredContentSize.width == 280, @"shared list preserves ChatGPT compact rows");
    NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:NSZeroPoint modifierFlags:0
        timestamp:0 windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:1];
    [fresh[0] mouseDown:click];
    NSCAssert(navigated == 1, @"fresh whole-row clicks still navigate");
    [pinButton(fresh[0]) performClick:nil];
    NSCAssert(pinned == 1, @"fresh pin remains a separate action");
    page.snapshot = nil; page.receivedAt = 0; [card update];
    NSArray *cached = rows(card.view);
    NSCAssert(cached.count == 2 && !pinButton(cached[0]).enabled, @"cached metadata keeps rows but disables pin editing");
    [cached[0] mouseDown:click];
    NSCAssert(navigated == 2, @"cached conversation links remain usable after generic component migration");
    for (NSView *row in cached) for (NSView *child in row.subviews)
        NSCAssert(![child isKindOfClass:NSProgressIndicator.class] && ![child.accessibilityLabel isEqual:@"Unread"], @"cached rows hide website status");
    [card stop];
    [DPTabIntegrationCacheForPage(page) invalidate];
    DPTimedOutCard *empty = [[DPTimedOutCard alloc] initWithIntegration:&site tab:tab];
    (void)empty.view; [empty update];
    BOOL unavailable = NO;
    for (NSView *child in empty.view.subviews) if ([child isKindOfClass:NSTextField.class])
        unavailable |= [[(NSTextField *)child stringValue] containsString:@"Conversations unavailable"];
    NSCAssert(unavailable, @"production card still exits loading without data");
    [empty stop];
    puts("chatgpt-preview-card: shared rendering, whole-row navigation, live/cached pin and bounded loading passed");
}}
