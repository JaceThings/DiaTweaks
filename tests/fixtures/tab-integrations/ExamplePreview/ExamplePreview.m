#import "TabIntegrations/TabIntegrations.h"
#import "TabIntegrations/ListPreview.h"

extern DPPatch DPExamplePreview;

@interface DPExamplePreviewList : DPTabIntegrationListPreview
@end

@implementation DPExamplePreviewList
- (DPTabIntegrationListContent *)listContent {
    NSDictionary *snapshot = self.context.snapshot;
    NSString *title = [snapshot[@"title"] isKindOfClass:NSString.class] ? snapshot[@"title"] : nil;
    NSMutableArray<DPTabIntegrationItem *> *items = [NSMutableArray array];
    if (title.length) [items addObject:[[DPTabIntegrationItem alloc] initWithTitle:title]];

    DPTabIntegrationListContent *content = [[DPTabIntegrationListContent alloc]
        initWithTitle:@"ExamplePreview" items:items];
    content.state = title.length ? @"live" : @"loading";
    content.emptyMessage = DPTabIntegrationDefaultEmptyMessage(content.state,
        NSDate.timeIntervalSinceReferenceDate - self.startedAt);
    return content;
}
@end

static DPTabIntegrationPreview *makePreview(DPTabIntegration *site, id tab) {
    return [[DPExamplePreviewList alloc] initWithIntegration:site tab:tab];
}

static void snapshotChanged(DPTabIntegrationPage *page) {
    id title = page.snapshot[@"title"];
    NSDictionary *value = [title isKindOfClass:NSString.class] && [title length] > 0 && [title length] <= 300
        ? @{ @"title": title } : nil;
    [DPTabIntegrationCacheForPage(page) observeValue:value scope:@"example.com" receivedAt:page.receivedAt];
}

static DPTabIntegration site = {
    .patch = &DPExamplePreview,
    .origins = DPIntegrationOrigins("https://example.com"),
    .scriptKey = @"ExamplePreview",
    .scriptNamespace = @"DiaExamplePreview",
    .scriptVersion = 1,
    .snapshotChanged = snapshotChanged,
    .makePreview = makePreview,
};

static void install(void) { DPTabIntegrationInstall(&site); }
static void apply(DPPatch *patch) { DPTabIntegrationApply(&site); }
static NSString *verify(DPPatch *patch) { return DPTabIntegrationVerify(&site); }

DP_PATCH(DPExamplePreview) {
    .key = @"examplePreview",
    .title = @"Example Tab Preview",
    .detail = @"Show example.com’s page title in a tab preview.",
    .symbol = @"globe",
    .section = @"Sidebar & Tab Bar",
    .classes = DPTabIntegrationClasses,
    .install = install, .apply = apply, .verify = verify,
};
