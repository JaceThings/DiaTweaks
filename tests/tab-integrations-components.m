#import "TabIntegrations/ListPreview.h"
#import <objc/message.h>

@interface DPTabIntegrationContext ()
@end
@implementation DPTabIntegrationContext
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab { return [super init]; }
- (NSDictionary *)snapshot { return @{}; }
- (DPTabIntegrationCache *)cache { return nil; }
- (NSTimeInterval)receivedAt { return 0; }
- (NSString *)URLString { return @"https://example.test/"; }
- (void)observeChanges:(void (^)(void))changed {}
- (void)stopObserving {}
- (void)refresh {}
- (void)performCommand:(NSString *)method arguments:(NSArray *)arguments {}
@end

@interface DPTabIntegrationPreview ()
@property(nonatomic, strong, readwrite) DPTabIntegrationContext *context;
@property(nonatomic, readwrite) NSTimeInterval startedAt;
@end
@implementation DPTabIntegrationPreview
- (instancetype)initWithIntegration:(DPTabIntegration *)integration tab:(id)tab {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _integration = integration; _tab = tab;
        _context = [DPTabIntegrationContext new];
        _startedAt = NSDate.timeIntervalSinceReferenceDate;
    }
    return self;
}
- (void)navigateToURL:(NSString *)url {}
- (void)update {}
- (void)stop {}
@end

@interface DPFixtureListPreview : DPTabIntegrationListPreview
@property(nonatomic, strong) DPTabIntegrationListContent *content;
@end
@implementation DPFixtureListPreview
- (DPTabIntegrationListContent *)listContent { return self.content; }
@end

@interface DPArbitraryPreview : DPTabIntegrationPreview
@end
@implementation DPArbitraryPreview
- (void)loadView { self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 90)]; }
@end

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    __block NSInteger opened = 0, archived = 0;
    DPTabIntegrationItem *mail = [[DPTabIntegrationItem alloc] initWithTitle:@"Invoice from Acme"];
    mail.identifier = @"mail-1";
    mail.subtitle = @"From Acme · Yesterday";
    mail.primaryAction = [[DPTabIntegrationAction alloc] initWithTitle:@"Open message" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *item) { opened++; }];
    DPTabIntegrationAction *archive = [[DPTabIntegrationAction alloc] initWithTitle:@"Archive message" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *item) { archived++; }];
    archive.symbolName = @"archivebox";
    mail.actions = @[archive];
    DPTabIntegrationListContent *mailContent = [[DPTabIntegrationListContent alloc] initWithTitle:@"Mail" items:@[mail]];
    mailContent.state = @"live";
    DPFixtureListPreview *preview = [[DPFixtureListPreview alloc] initWithIntegration:NULL tab:nil];
    preview.content = mailContent;
    [preview loadView];
    [preview update];
    NSView *row = preview.view.subviews[1];
    NSCAssert([row isKindOfClass:NSView.class] && row.frame.size.height == 48, @"mail-like subtitle receives a two-line compact row");
    NSButton *archiveButton = nil;
    for (NSView *child in row.subviews) if ([child isKindOfClass:NSButton.class]) archiveButton = (NSButton *)child;
    NSCAssert(archiveButton && [archiveButton.accessibilityLabel isEqual:@"Archive message"], @"custom action has an accessible separate control");
    NSPoint actionPoint = NSMakePoint(row.frame.origin.x + NSMinX(archiveButton.frame) + 4,
        row.frame.origin.y + NSMinY(archiveButton.frame) + 4);
    NSView *actionHit = [row hitTest:actionPoint];
    NSCAssert(actionHit == archiveButton || [actionHit isDescendantOf:archiveButton], @"action button retains its own hit target");
    [archiveButton performClick:nil];
    NSCAssert(archived == 1 && opened == 0, @"secondary action does not trigger row activation");
    NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:1];
    [row mouseDown:click];
    NSCAssert(opened == 1, @"whole row activates the primary action");

    preview.content = [[DPTabIntegrationListContent alloc] initWithTitle:@"Mail" items:@[]];
    preview.content.state = @"loading";
    [preview update];
    NSTextField *loading = nil;
    for (NSView *child in preview.view.subviews) if ([child isKindOfClass:NSTextField.class] && [((NSTextField *)child).stringValue containsString:@"Loading"]) loading = (NSTextField *)child;
    NSCAssert(loading, @"loading state uses a standard bounded message");
    preview.startedAt = NSDate.timeIntervalSinceReferenceDate - 8;
    [preview update];
    BOOL unavailable = NO;
    for (NSView *child in preview.view.subviews) if ([child isKindOfClass:NSTextField.class] && [((NSTextField *)child).stringValue containsString:@"unavailable"]) unavailable = YES;
    NSCAssert(unavailable, @"loading timer transition refreshes without another snapshot change");

    __block NSView *providedView = nil;
    DPTabIntegrationItem *order = [[DPTabIntegrationItem alloc] initWithTitle:@"Order 1042"];
    order.subtitle = @"2 items · $48.00";
    order.representedObject = @{@"phase":@"delivered", @"progress":@1};
    order.viewProvider = ^NSView *(DPTabIntegrationItem *item, DPTabIntegrationContext *context) {
        NSCAssert([item.representedObject[@"phase"] isEqual:@"delivered"], @"custom rows receive provider-owned metadata");
        NSView *custom = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 256, 72)];
        custom.identifier = @"order-card-content";
        providedView = custom;
        return custom;
    };
    preview.content = [[DPTabIntegrationListContent alloc] initWithTitle:@"Orders" items:@[order]];
    preview.content.revision = @"order-rev-1";
    [preview update];
    NSCAssert(providedView && [providedView.identifier isEqual:@"order-card-content"], @"item provider can insert arbitrary native order content");
    NSCAssert(NSHeight(providedView.frame) == 72 && NSHeight(preview.view.subviews.lastObject.frame) == 72,
        @"custom content retains its preferred row height");

    DPTabIntegrationAction *pin = [[DPTabIntegrationAction alloc] initWithTitle:@"Pin" handler:nil];
    pin.symbolName = @"pin";
    DPTabIntegrationItem *cachedItem = [[DPTabIntegrationItem alloc] initWithTitle:@"Cached item"];
    cachedItem.actions = @[pin];
    preview.content = [[DPTabIntegrationListContent alloc] initWithTitle:@"Orders" items:@[cachedItem]];
    preview.content.state = @"cached";
    [preview update];
    NSButton *disabled = nil;
    for (NSView *candidate in preview.view.subviews)
        for (NSView *child in candidate.subviews) if ([child isKindOfClass:NSButton.class]) disabled = (NSButton *)child;
    NSCAssert(disabled && !disabled.enabled, @"cached state disables actions unless explicitly allowed");
    NSCAssert([preview.view.subviews.firstObject isKindOfClass:NSTextField.class], @"cached state retains the standard title and status header");
    NSCAssert([DPTabIntegrationDefaultEmptyMessage(@"loading", 1) containsString:@"Loading"], @"loading copy is immediate");
    NSCAssert(![DPTabIntegrationDefaultEmptyMessage(@"loading", 8) containsString:@"Loading…"], @"loading copy changes after the bounded wait");

    __block NSInteger cachedOpened = 0, overflowAction = 0;
    DPTabIntegrationItem *longRow = [[DPTabIntegrationItem alloc] initWithTitle:[@"Very long order title " stringByPaddingToLength:240 withString:@"order " startingAtIndex:0]];
    longRow.subtitle = [@"Very long customer subtitle " stringByPaddingToLength:200 withString:@"customer " startingAtIndex:0];
    longRow.statusText = @"Needs review";
    longRow.working = YES; longRow.unread = YES;
    longRow.primaryAction = [[DPTabIntegrationAction alloc] initWithTitle:@"Open order" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *item) { cachedOpened++; }];
    longRow.primaryAction.enabledWhenCached = YES;
    NSMutableArray *manyActions = [NSMutableArray new];
    for (NSUInteger i = 0; i < 5; i++) {
        DPTabIntegrationAction *action = [[DPTabIntegrationAction alloc] initWithTitle:[NSString stringWithFormat:@"Action %lu", (unsigned long)i] handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *item) { overflowAction++; }];
        action.symbolName = @"ellipsis";
        [manyActions addObject:action];
    }
    longRow.actions = manyActions;
    preview.content = [[DPTabIntegrationListContent alloc] initWithTitle:@"Orders" items:@[longRow]];
    preview.content.state = @"cached";
    [preview update];
    NSView *longStandardRow = nil;
    for (NSView *candidate in preview.view.subviews) if (candidate.subviews.count > 2) longStandardRow = candidate;
    NSCAssert(longStandardRow, @"long order row rendered");
    NSView *titleLabel = nil, *subtitleLabel = nil, *detailLabel = nil, *moreButton = nil;
    for (NSView *child in longStandardRow.subviews) {
        if ([child isKindOfClass:NSTextField.class] && !titleLabel) titleLabel = child;
        else if ([child isKindOfClass:NSTextField.class] && !subtitleLabel) subtitleLabel = child;
        else if ([child isKindOfClass:NSTextField.class]) detailLabel = child;
        if ([child isKindOfClass:NSButton.class] && [child.accessibilityLabel isEqual:@"More actions"]) moreButton = child;
        NSCAssert(NSContainsRect(longStandardRow.bounds, child.frame), @"long row content stays within the compact row");
    }
    NSCAssert(titleLabel && subtitleLabel && detailLabel && NSIntersectionRect(subtitleLabel.frame, detailLabel.frame).size.height == 0,
        @"subtitle and status never overlap");
    NSCAssert(moreButton && ((NSButton *)moreButton).menu.numberOfItems == 3, @"additional actions remain reachable through an accessible overflow menu");
    NSCAssert(((NSButton *)moreButton).target == moreButton && ((NSButton *)moreButton).action == NSSelectorFromString(@"showActions:"),
        @"overflow has a left-click action instead of only a context menu");
    NSCAssert(!((NSButton *)moreButton).menu.autoenablesItems, @"AppKit must not re-enable cached actions automatically");
    NSCAssert(longStandardRow.subviews.count == 6, @"cached rows centrally suppress working and unread indicators");
    [longStandardRow mouseDown:click];
    NSCAssert(cachedOpened == 1, @"primary open action remains enabled for cached data when explicitly allowed");
    NSMenuItem *overflowItem = ((NSButton *)moreButton).menu.itemArray.firstObject;
    NSCAssert(!overflowItem.enabled, @"cached state also disables actions in the overflow menu");
    preview.content.state = @"live";
    [preview update];
    for (NSView *candidate in preview.view.subviews)
        for (NSView *child in candidate.subviews)
            if ([child isKindOfClass:NSButton.class] && [child.accessibilityLabel isEqual:@"More actions"]) moreButton = child;
    overflowItem = ((NSButton *)moreButton).menu.itemArray.firstObject;
    ((void (*)(id, SEL, id))objc_msgSend)(preview, NSSelectorFromString(@"performListMenuAction:"), overflowItem);
    NSCAssert(overflowAction == 1, @"overflow menu dispatches custom actions");

    NSMutableArray *inbox = [NSMutableArray new];
    for (NSUInteger i = 0; i < 20; i++) [inbox addObject:[[DPTabIntegrationItem alloc] initWithTitle:@"Synthetic mail"]];
    preview.content = [[DPTabIntegrationListContent alloc] initWithTitle:@"Inbox" items:inbox];
    [preview update];
    NSScrollView *scroll = nil;
    for (NSView *candidate in preview.view.subviews) if ([candidate isKindOfClass:NSScrollView.class]) scroll = (NSScrollView *)candidate;
    NSCAssert(scroll && scroll.documentView.subviews.count == 20 && preview.preferredContentSize.height == 420,
        @"long provider lists retain all items in the default scroll viewport");
    preview.content.maximumHeight = 0; [preview update];
    NSCAssert(preview.preferredContentSize.height > 420, @"a custom provider can opt out of the default list height cap");

    DPArbitraryPreview *arbitrary = [[DPArbitraryPreview alloc] initWithIntegration:NULL tab:nil];
    [arbitrary loadView];
    NSCAssert(arbitrary.view.frame.size.width == 200, @"custom previews can keep their own AppKit composition");
    puts("tab-integrations-components: generic rows, custom AppKit content, actions, state and custom previews passed");
}}
