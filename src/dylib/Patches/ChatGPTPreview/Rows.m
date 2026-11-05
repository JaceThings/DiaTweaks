#import "ChatGPTPreview.h"

NSView *DPChatGPTConversationRow(NSDictionary *row, BOOL pinned, void (^open)(void), void (^pin)(void)) {
    NSView *view = DPTabIntegrationRow(row[@"title"], [row[@"activity"] isEqual:@"generating"], [row[@"unread"] boolValue], pinned, open, pin ?: ^{});
    if (!pin) for (NSView *child in view.subviews)
        if ([child isKindOfClass:NSButton.class] && ((NSButton *)child).action == NSSelectorFromString(@"pinRow:"))
            ((NSButton *)child).enabled = NO;
    if ([@[@"unknown", @"stale"] containsObject:row[@"activity"]])
        view.toolTip = [row[@"title"] stringByAppendingString:@"\nOpen this conversation to check its live status."];
    return view;
}
