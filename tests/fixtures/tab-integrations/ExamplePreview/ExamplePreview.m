// Copy this folder into src/dylib/Patches to try a second website adapter.
#import "TabIntegrations/TabIntegrations.h"

extern DPPatch DPExamplePreview;
@interface DPExampleCard : DPTabIntegrationPreview
@property(nonatomic, strong) NSTimer *refresh;
- (void)update;
@end
@implementation DPExampleCard
- (void)viewDidLoad {
    [super viewDidLoad];
    __weak DPExampleCard *weak = self;
    self.refresh = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *_) { [weak update]; }];
    [NSRunLoop.mainRunLoop addTimer:self.refresh forMode:NSRunLoopCommonModes];
    [self update];
}
- (void)update {
    DPTabIntegrationPage *page = DPTabIntegrationPageForTab(self.integration, self.tab);
    DPTabIntegrationCache *cache = DPTabIntegrationCacheForPage(page);
    id title = [cache valueAtTime:NSDate.timeIntervalSinceReferenceDate][@"title"];
    if (![title isKindOfClass:NSString.class] || ![title length]) title = @"Loading example.com…";
    for (NSView *child in self.view.subviews.copy) [child removeFromSuperview];
    __weak DPExampleCard *weak = self;
    NSView *row = DPTabIntegrationRow(title, NO, NO, NO, ^{ [weak navigateToURL:@"https://example.com/"]; }, nil);
    row.frame = NSMakeRect(12, 10, 256, 36);
    [self.view addSubview:row];
    self.preferredContentSize = NSMakeSize(280, 56);
}
- (void)stop { [self.refresh invalidate]; self.refresh = nil; }
- (void)dealloc { [self.refresh invalidate]; }
@end

static DPTabIntegrationPreview *makePreview(DPTabIntegration *site, id tab) {
    return [[DPExampleCard alloc] initWithIntegration:site tab:tab];
}
static void snapshotChanged(DPTabIntegrationPage *page) {
    if (!page.snapshot) return;
    id title = page.snapshot[@"title"];
    NSDictionary *value = [title isKindOfClass:NSString.class] && [title length] > 0 && [title length] <= 300 ? @{@"title":title} : nil;
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
    .classes = DPClasses(DPDiaBrowser, DPDiaBrowserDelegate, DPDiaTabView, DPDiaPinnedTab, "ArcWebContents"),
    .install = install, .apply = apply, .verify = verify,
};
