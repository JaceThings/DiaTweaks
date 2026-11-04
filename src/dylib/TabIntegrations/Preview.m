#import "Internal.h"

@implementation DPTabIntegrationPreview
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _integration = integration;
        _tab = tab;
        [super setPreferredContentSize:NSMakeSize(280, 120)];
    }
    return self;
}

- (void)loadView { self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 120)]; }
- (void)stop {}

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
