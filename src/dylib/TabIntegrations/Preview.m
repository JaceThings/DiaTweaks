#import "Internal.h"

@interface DPTabIntegrationPreview ()
@property(nonatomic, strong) DPTabIntegrationContext *context;
@property(nonatomic) NSTimeInterval startedAt;
@end
@implementation DPTabIntegrationPreview
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _integration = integration;
        _tab = tab;
        _context = [[DPTabIntegrationContext alloc] initWithIntegration:integration tab:tab];
        [super setPreferredContentSize:NSMakeSize(280, 120)];
    }
    return self;
}

- (void)loadView { self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 120)]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.startedAt = NSDate.timeIntervalSinceReferenceDate;
    __weak DPTabIntegrationPreview *weak = self;
    [self.context observeChanges:^{ [weak update]; }];
}
- (void)update {}
- (void)stop { [self.context stopObserving]; }
- (void)dealloc { [self.context stopObserving]; }

- (void)setPreferredContentSize:(NSSize)size {
    if (NSEqualSizes(size, self.preferredContentSize)) return;
    [super setPreferredContentSize:size];
    if (self.sizeChanged) self.sizeChanged(size);
}

- (void)navigateToURL:(NSString *)url {
    DPTabIntegrationNavigateTab(self.integration, self.tab, url);
    DPDismissIntegrationHover();
}
@end
