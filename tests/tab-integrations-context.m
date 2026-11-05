#import "TabIntegrations/Internal.h"
#import "TabIntegrations/Scheduler.h"

@interface DPContextTab : NSObject
@property(nonatomic, copy) NSString *URL;
@end
@implementation DPContextTab
@end
static DPTabIntegrationPage *fixturePage;
static NSUInteger reads, commands, updates, navigations;
BOOL DPTabIntegrationEnabled(DPTabIntegration *site) { return site && site->patch->on; }
DPTabIntegrationPage *DPTabIntegrationPageForTab(DPTabIntegration *site, id tab) {
    return DPTabIntegrationEnabled(site) && [tab URL] ? fixturePage : nil;
}
void DPTabIntegrationRead(DPTabIntegrationPage *page) { if (page) reads++; }
void DPTabIntegrationCommand(DPTabIntegrationPage *page, NSString *method, NSArray *arguments) {
    if (page && [method isEqual:@"markRead"] && [arguments isEqual:@[@"mail-1"]]) commands++;
}
void DPTabIntegrationNavigateTab(DPTabIntegration *site, id tab, NSString *url) { navigations++; }
void DPDismissIntegrationHover(void) {}
@implementation DPTabIntegrationPage
@end

@interface DPCustomSummaryPreview : DPTabIntegrationPreview
@end
@implementation DPCustomSummaryPreview
- (void)loadView { self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 180)]; }
- (void)update { updates++; }
@end

int main(void) { @autoreleasepool {
    DPPatch patch = {.key=@"contextFixture", .on=YES};
    DPTabIntegration site = {.patch=&patch};
    DPContextTab *tab = [DPContextTab new]; tab.URL = @"https://example.com/inbox";
    fixturePage = [DPTabIntegrationPage new]; fixturePage.integration = &site;
    // Keep fixture transport identities alive: production pages intentionally own neither.
    NSObject *browser = [NSObject new], *contents = [NSObject new];
    fixturePage.browser = browser; fixturePage.contents = contents;
    fixturePage.snapshot = @{@"tracking":@{@"phase":@"delivered"}, @"summary":@"Synthetic summary"};
    fixturePage.receivedAt = 100; fixturePage.diagnosticCode = @"ready";
    DPTabIntegrationContext *context = [[DPTabIntegrationContext alloc] initWithIntegration:&site tab:tab];
    NSCAssert(context.snapshot[@"tracking"] && [context.URLString isEqual:tab.URL], @"context does not impose a list schema");
    [context.cache observeValue:fixturePage.snapshot scope:@"account-a" receivedAt:100];
    NSDictionary *diagnostics = DPIntegrationDiagnostics(fixturePage, 101);
    NSCAssert([diagnostics[@"cache"] isEqual:@"fresh"] && [diagnostics[@"lastSuccessAge"] doubleValue] == 1, @"fresh diagnostics");
    NSCAssert([DPIntegrationDiagnostics(fixturePage, 107)[@"cache"] isEqual:@"cached"], @"freshness deadlines work without new snapshots");
    NSCAssert(![[diagnostics description] containsString:@"Synthetic"] && ![[diagnostics description] containsString:@"https"], @"diagnostics omit content and URLs");
    NSUInteger observed = 0; __block NSUInteger callbacks = 0;
    [context observeChanges:^{ callbacks++; }]; observed = callbacks;
    NSCAssert(reads == 1 && observed == 1 && DPIntegrationPageIsObserved(fixturePage), @"observation refreshes and subscribes once");
    DPIntegrationRunScheduledTick(110);
    NSCAssert(callbacks == observed + 1, @"the shared scheduler notifies arbitrary previews");
    [context performCommand:@"markRead" arguments:@[@"mail-1"]];
    NSCAssert(commands == 1, @"commands are not limited to pinning");
    [context stopObserving]; DPIntegrationRunScheduledTick(111);
    NSCAssert(callbacks == observed + 1 && !DPIntegrationPageIsObserved(fixturePage), @"stop removes subscription");
    __weak DPTabIntegrationContext *released;
    @autoreleasepool {
        DPTabIntegrationContext *temporary = [[DPTabIntegrationContext alloc] initWithIntegration:&site tab:tab];
        [temporary observeChanges:^{}]; released = temporary;
    }
    NSCAssert(!released && !DPIntegrationPageIsObserved(fixturePage), @"observation cannot retain its context");
    __block NSUInteger firstTicks = 0, secondTicks = 0;
    __block DPIntegrationSubscription *second;
    DPIntegrationSubscription *first = DPIntegrationSchedule(^(NSTimeInterval now) { firstTicks++; [second cancel]; });
    second = DPIntegrationSchedule(^(NSTimeInterval now) { secondTicks++; });
    DPIntegrationRunScheduledTick(112); [first cancel]; NSUInteger lastSecond = secondTicks;
    DPIntegrationRunScheduledTick(113);
    NSCAssert(firstTicks == 1 && secondTicks == lastSecond, @"cancellation during dispatch is safe");
    DPCustomSummaryPreview *custom = [[DPCustomSummaryPreview alloc] initWithIntegration:&site tab:tab];
    (void)custom.view;
    NSUInteger before = updates; DPIntegrationRunScheduledTick(114);
    NSCAssert(updates == before + 1 && custom.view.frame.size.width == 400, @"custom views retain freedom and common lifecycle");
    [custom navigateToURL:@"https://example.com/summary"];
    NSCAssert(navigations == 1, @"custom views retain exact-tab navigation entry point");
    [custom stop]; before = updates; DPIntegrationRunScheduledTick(115);
    NSCAssert(updates == before, @"stopping a custom preview cancels common refresh");
    patch.on = NO;
    NSCAssert([context.diagnostics[@"code"] isEqual:@"disabled"], @"disabled state is explicit");
    puts("tab-integrations-context: arbitrary schemas/views, observation, commands, cancellation and diagnostics passed");
}}
