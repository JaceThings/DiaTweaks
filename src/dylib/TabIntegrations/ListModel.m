#import "ListRows.h"

static NSString *DPListString(id value) { return [value isKindOfClass:NSString.class] ? value : @""; }

static DPTabIntegrationAction *DPListSafeAction(id candidate) {
    if (![candidate isKindOfClass:DPTabIntegrationAction.class]) return nil;
    DPTabIntegrationAction *source = candidate;
    DPTabIntegrationAction *action = [[DPTabIntegrationAction alloc] initWithTitle:DPListString(source.title) handler:source.handler];
    action.symbolName = [source.symbolName isKindOfClass:NSString.class] ? source.symbolName : nil;
    action.accessibilityTitle = [source.accessibilityTitle isKindOfClass:NSString.class] ? source.accessibilityTitle : nil;
    action.enabled = source.enabled;
    action.enabledWhenCached = source.enabledWhenCached;
    return action;
}

DPTabIntegrationListContent *DPIntegrationListSafeContent(id candidate) {
    if (![candidate isKindOfClass:DPTabIntegrationListContent.class])
        return [[DPTabIntegrationListContent alloc] initWithTitle:@"" items:@[]];
    DPTabIntegrationListContent *source = candidate;
    NSArray *sourceItems = [source.items isKindOfClass:NSArray.class] ? source.items : @[];
    NSMutableArray *items = [NSMutableArray new];
    for (id candidateItem in sourceItems) {
        if (![candidateItem isKindOfClass:DPTabIntegrationItem.class]) continue;
        DPTabIntegrationItem *sourceItem = candidateItem;
        DPTabIntegrationItem *item = [[DPTabIntegrationItem alloc] initWithTitle:DPListString(sourceItem.title)];
        item.identifier = [sourceItem.identifier isKindOfClass:NSString.class] ? sourceItem.identifier : nil;
        item.representedObject = sourceItem.representedObject;
        item.subtitle = [sourceItem.subtitle isKindOfClass:NSString.class] ? sourceItem.subtitle : nil;
        item.statusText = [sourceItem.statusText isKindOfClass:NSString.class] ? sourceItem.statusText : nil;
        item.toolTip = [sourceItem.toolTip isKindOfClass:NSString.class] ? sourceItem.toolTip : nil;
        item.working = sourceItem.working; item.unread = sourceItem.unread; item.pinned = sourceItem.pinned;
        item.viewProvider = sourceItem.viewProvider;
        item.primaryAction = DPListSafeAction(sourceItem.primaryAction);
        NSMutableArray *actions = [NSMutableArray new];
        if ([sourceItem.actions isKindOfClass:NSArray.class])
            for (id action in sourceItem.actions) { DPTabIntegrationAction *safe = DPListSafeAction(action); if (safe) [actions addObject:safe]; }
        item.actions = actions;
        [items addObject:item];
    }
    DPTabIntegrationListContent *content = [[DPTabIntegrationListContent alloc] initWithTitle:DPListString(source.title) items:items];
    content.state = DPListString(source.state).length ? DPListString(source.state) : @"empty";
    content.emptyMessage = [source.emptyMessage isKindOfClass:NSString.class] ? source.emptyMessage : nil;
    content.footerMessage = [source.footerMessage isKindOfClass:NSString.class] ? source.footerMessage : nil;
    content.statusText = [source.statusText isKindOfClass:NSString.class] ? source.statusText : nil;
    content.revision = [source.revision isKindOfClass:NSString.class] ? source.revision : nil;
    content.maximumHeight = isfinite(source.maximumHeight) ? MAX(0, source.maximumHeight) : 420;
    return content;
}

NSArray *DPIntegrationListSignature(DPTabIntegrationListContent *content, NSString *effectiveEmptyMessage) {
    NSMutableArray *items = [NSMutableArray new];
    for (DPTabIntegrationItem *item in content.items ?: @[]) {
        NSMutableArray *actions = [NSMutableArray new];
        for (DPTabIntegrationAction *action in item.actions ?: @[])
            [actions addObject:@[action.title ?: @"", action.symbolName ?: @"", action.accessibilityTitle ?: @"", @(action.enabled), @(action.enabledWhenCached)]];
        DPTabIntegrationAction *primary = item.primaryAction;
        [items addObject:@[item.title ?: @"", item.identifier ?: @"", item.subtitle ?: @"", item.statusText ?: @"",
            item.toolTip ?: @"", @(item.working), @(item.unread), @(item.pinned), @(primary != nil),
            primary.title ?: @"", @(primary.enabled), @(primary.enabledWhenCached), @(item.viewProvider != nil), actions]];
    }
    return @[content.title ?: @"", content.state ?: @"", content.statusText ?: @"", effectiveEmptyMessage ?: @"",
        content.footerMessage ?: @"", content.revision ?: @"", items, @(content.maximumHeight)];
}
