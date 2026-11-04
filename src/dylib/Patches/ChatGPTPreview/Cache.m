#import "Cache.h"

static NSDictionary *DPSafeSession(id row) {
    if (![row isKindOfClass:NSDictionary.class] || !DPChatGPTConversationURL(row[@"id"])) return nil;
    NSString *title = row[@"title"];
    if (![title isKindOfClass:NSString.class] || !title.length || title.length > 300) return nil;
    NSString *activity = [@[@"generating", @"idle", @"unknown", @"stale"] containsObject:row[@"activity"]] ? row[@"activity"] : @"unknown";
    return @{@"id":row[@"id"], @"title":title, @"activity":activity,
        @"unread":@([row[@"unread"] isKindOfClass:NSNumber.class] && [row[@"unread"] boolValue])};
}

NSDictionary *DPChatGPTCachePresentation(DPTabIntegrationCache *cache, NSDictionary *snapshot,
                                       NSTimeInterval receivedAt, NSTimeInterval now) {
    NSString *scope = [snapshot[@"scopeKey"] isKindOfClass:NSString.class] ? snapshot[@"scopeKey"] : nil;
    BOOL knownScope = scope.length > 8 && scope.length <= 512
        && ([scope hasPrefix:@"account:"] || [scope hasPrefix:@"transient:"]);
    BOOL ready = knownScope && [snapshot[@"sourceLoaded"] isKindOfClass:NSNumber.class] && [snapshot[@"sourceLoaded"] boolValue]
        && [@[@"ready", @"empty"] containsObject:snapshot[@"sourceStatus"]]
        && [snapshot[@"recent"] isKindOfClass:NSArray.class];
    NSMutableArray *rows = [NSMutableArray new];
    NSDictionary *pinned = DPSafeSession(snapshot[@"pinned"]);
    if (pinned) [rows addObject:[pinned mutableCopy]];
    if (ready) for (id candidate in snapshot[@"recent"]) {
        NSDictionary *row = DPSafeSession(candidate);
        if (!row || [[rows valueForKey:@"id"] containsObject:row[@"id"]]) continue;
        if (rows.count >= (pinned ? 4 : 3)) break;
        [rows addObject:[row mutableCopy]];
    }
    // A malformed nonempty result is not evidence that the real sidebar became empty.
    if (ready && [snapshot[@"recent"] count] && !rows.count) ready = NO;
    [cache observeValue:ready ? @{@"rows":rows, @"pin":pinned ?: @{}} : nil
                  scope:knownScope ? scope : nil receivedAt:receivedAt];
    NSDictionary *value = [cache valueAtTime:now];
    if (!value) return @{@"rows":@[], @"pin":@{}, @"state":@"missing"};
    BOOL cached = ![cache isFreshAtTime:now];
    NSMutableArray *presented = [NSMutableArray new];
    for (NSDictionary *row in value[@"rows"]) {
        NSMutableDictionary *copy = [row mutableCopy];
        if (cached) { copy[@"activity"] = @"stale"; copy[@"unread"] = @NO; }
        [presented addObject:copy];
    }
    return @{@"rows":presented, @"pin":value[@"pin"], @"state":cached ? @"cached" : @"live"};
}
void DPChatGPTSnapshotChanged(DPTabIntegrationPage *page) {
    if (page.snapshot) DPChatGPTCachePresentation(DPTabIntegrationCacheForPage(page), page.snapshot,
                                                 page.receivedAt, NSDate.timeIntervalSinceReferenceDate);
}
NSString *DPChatGPTEmptyMessage(NSString *state, NSTimeInterval elapsed) {
    if ([state isEqual:@"missing"]) return elapsed < 6 ? @"Loading conversations…" : @"Conversations unavailable. Open ChatGPT and try again.";
    return @"Open ChatGPT’s sidebar to see recent chats.";
}
