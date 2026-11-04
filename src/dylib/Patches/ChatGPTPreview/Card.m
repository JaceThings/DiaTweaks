#import "ChatGPTPreview.h"
#import "Cache.h"
#import "TabIntegrations/Components.h"
#import "TabIntegrations/ListPreview.h"

@implementation DPChatGPTCard
- (DPTabIntegrationListContent *)listContent {
    NSDictionary *data = DPChatGPTCachePresentation(self.context.cache, self.context.snapshot,
        self.context.receivedAt, NSDate.timeIntervalSinceReferenceDate);
    NSArray<NSDictionary *> *rows = data[@"rows"];
    NSDictionary *pinned = data[@"pin"];
    NSString *state = data[@"state"] ?: @"missing";
    NSString *message = DPChatGPTEmptyMessage(state, NSDate.timeIntervalSinceReferenceDate - self.startedAt);
    BOOL cached = [state isEqualToString:@"cached"];
    __weak DPChatGPTCard *weakSelf = self;
    NSMutableArray<DPTabIntegrationItem *> *items = [NSMutableArray new];
    for (NSDictionary *row in rows) {
        NSString *identifier = row[@"id"];
        BOOL isPinned = [identifier isEqual:pinned[@"id"]];
        DPTabIntegrationItem *item = [[DPTabIntegrationItem alloc] initWithTitle:row[@"title"] ?: @""];
        item.identifier = identifier;
        item.working = [row[@"activity"] isEqualToString:@"generating"];
        item.unread = [row[@"unread"] boolValue];
        item.pinned = isPinned;
        if ([@[@"unknown", @"stale"] containsObject:row[@"activity"]])
            item.toolTip = [item.title stringByAppendingString:@"\nOpen this conversation to check its live status."];
        item.primaryAction = [[DPTabIntegrationAction alloc] initWithTitle:@"Open conversation" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *selected) {
            NSString *url = DPChatGPTConversationURL(selected.identifier);
            if (url && DPChatGPTURL(context.URLString)) [weakSelf navigateToURL:url];
        }];
        item.primaryAction.enabledWhenCached = YES;
        DPTabIntegrationAction *pin = [[DPTabIntegrationAction alloc] initWithTitle:isPinned ? @"Unpin" : @"Pin" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *selected) {
            [context performCommand:@"pin" arguments:@[isPinned ? NSNull.null : selected.identifier]];
        }];
        pin.symbolName = isPinned ? @"pin.fill" : @"pin";
        pin.accessibilityTitle = pin.title;
        pin.enabledWhenCached = NO;
        item.actions = @[pin];
        [items addObject:item];
    }
    DPTabIntegrationListContent *content = [[DPTabIntegrationListContent alloc] initWithTitle:@"ChatGPT" items:items];
    content.state = cached ? @"cached" : ([state isEqualToString:@"live"] ? @"live" : @"empty");
    content.emptyMessage = message;
    content.statusText = cached ? @"Cached" : nil;
    return content;
}
@end
