#import "ConversationPreview.h"
#import "Components.h"

#import <CoreFoundation/CoreFoundation.h>

static BOOL DPConversationIsBoolean(id value) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL DPConversationIdentifierIsValid(id value) {
    if (![value isKindOfClass:NSString.class] || ![value length] || [value length] > 128) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"];
    return [value rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

static NSString *DPConversationURL(id value, DPTabIntegration *integration) {
    if (![value isKindOfClass:NSString.class] || ![value length] || [value length] > 4096) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    if (!parts || parts.user.length || parts.password.length || parts.query != nil || parts.fragment != nil
        || !DPTabIntegrationMatchesURL(integration, value)) return nil;
    return parts.string;
}

static NSDictionary *DPConversationValidatedRow(id candidate, DPTabIntegration *integration) {
    if (![candidate isKindOfClass:NSDictionary.class]) return nil;
    id identifier = candidate[@"id"], title = candidate[@"title"], urlValue = candidate[@"url"];
    id activity = candidate[@"activity"], unread = candidate[@"unread"];
    if (!DPConversationIdentifierIsValid(identifier) || ![title isKindOfClass:NSString.class]
        || ![title length] || [title length] > 300 || !DPConversationIsBoolean(unread)
        || ![activity isKindOfClass:NSString.class]
        || ![@[@"generating", @"idle", @"unknown"] containsObject:activity]) return nil;
    NSString *url = DPConversationURL(urlValue, integration);
    if (!url) return nil;
    return @{ @"id":identifier, @"title":title, @"url":url,
              @"activity":activity, @"unread":([activity isEqual:@"generating"] ? @NO : unread) };
}

static NSDictionary *DPConversationValidatedSnapshot(NSDictionary *snapshot, DPTabIntegration *integration) {
    if (![snapshot isKindOfClass:NSDictionary.class]) return nil;
    id scope = snapshot[@"scopeKey"], sourceStatus = snapshot[@"sourceStatus"];
    id recent = snapshot[@"recent"], pinned = snapshot[@"pinned"];
    if (!(scope == NSNull.null || ([scope isKindOfClass:NSString.class] && [scope length] <= 512))
        || ![sourceStatus isKindOfClass:NSString.class]
        || ![@[@"ready", @"empty", @"unavailable", @"signed-out", @"identity-lost"] containsObject:sourceStatus]
        || ![recent isKindOfClass:NSArray.class]
        || !(pinned == NSNull.null || [pinned isKindOfClass:NSDictionary.class])) return nil;
    if ([sourceStatus isEqual:@"empty"] && [recent count] != 0) return nil;

    NSDictionary *safePinned = pinned == NSNull.null ? nil : DPConversationValidatedRow(pinned, integration);
    NSMutableArray *safeRecent = [NSMutableArray new];
    NSMutableSet *seen = [NSMutableSet new];
    if (safePinned) [seen addObject:safePinned[@"id"]];
    for (id candidate in [recent subarrayWithRange:NSMakeRange(0, MIN([recent count], 120))]) {
        NSDictionary *row = DPConversationValidatedRow(candidate, integration);
        if (!row || [seen containsObject:row[@"id"]]) continue;
        [seen addObject:row[@"id"]];
        if (safeRecent.count < 3) [safeRecent addObject:row];
    }
    // A nonempty payload made entirely of invalid rows cannot prove the sidebar is empty.
    if ([recent count] && !safePinned && !safeRecent.count) return nil;
    return @{ @"scopeKey":scope, @"sourceStatus":sourceStatus,
              @"recent":safeRecent, @"pinned":safePinned ?: NSNull.null };
}

static NSArray *DPConversationRowsFromSnapshot(NSDictionary *validated) {
    NSMutableArray *rows = [NSMutableArray new];
    NSDictionary *pinned = validated[@"pinned"];
    if ([pinned isKindOfClass:NSDictionary.class]) [rows addObject:pinned];
    [rows addObjectsFromArray:validated[@"recent"] ?: @[]];
    return rows;
}

static NSDictionary *DPConversationVisibleValue(NSDictionary *value, BOOL cached, NSString *state) {
    NSMutableArray *rows = [NSMutableArray new];
    for (NSDictionary *row in value[@"rows"] ?: @[]) {
        NSMutableDictionary *copy = [row mutableCopy];
        if (cached) { copy[@"activity"] = @"unknown"; copy[@"unread"] = @NO; }
        [rows addObject:copy];
    }
    return @{ @"rows":rows, @"pin":value[@"pin"] ?: NSNull.null, @"state":state };
}

NSDictionary *DPConversationPresentation(DPTabIntegrationCache *cache, NSDictionary *snapshot,
                                        DPTabIntegration *integration, NSTimeInterval receivedAt,
                                        NSTimeInterval now) {
    if (!cache || !integration) return @{ @"rows":@[], @"pin":NSNull.null, @"state":@"unavailable" };
    if (!snapshot) {
        // A missing transport result says nothing about identity. Keep a prior scoped
        // value stale; only an explicit null scope in a received snapshot fails closed.
        [cache observeValue:nil scope:nil receivedAt:receivedAt];
        NSDictionary *value = [cache valueAtTime:now];
        if (!value) return @{ @"rows":@[], @"pin":NSNull.null, @"state":@"unavailable" };
        return DPConversationVisibleValue(value, YES, @"cached");
    }
    NSDictionary *validated = DPConversationValidatedSnapshot(snapshot, integration);
    NSString *scope = [validated[@"scopeKey"] isKindOfClass:NSString.class] ? validated[@"scopeKey"] : nil;
    NSString *status = validated[@"sourceStatus"];

    // Even when rows fail validation, a well-formed scope still marks an identity
    // transition and must prevent data from a previous account from surviving it.
    if (!validated && [snapshot isKindOfClass:NSDictionary.class]) {
        id rawScope = snapshot[@"scopeKey"], rawStatus = snapshot[@"sourceStatus"];
        if ([rawStatus isKindOfClass:NSString.class]
            && ([(NSString *)rawStatus isEqual:@"signed-out"] || [(NSString *)rawStatus isEqual:@"identity-lost"])) {
            [cache invalidate];
            NSString *logoutState = [(NSString *)rawStatus isEqual:@"signed-out"] ? @"signedOut" : @"unavailable";
            return @{ @"rows":@[], @"pin":NSNull.null, @"state":logoutState };
        }
        if ([rawScope isKindOfClass:NSString.class] && [rawScope length] <= 512) scope = rawScope;
        if ([rawStatus isKindOfClass:NSString.class]) status = rawStatus;
    }

    if (validated && ([status isEqual:@"signed-out"] || [status isEqual:@"identity-lost"])) {
        [cache invalidate];
        return @{ @"rows":@[], @"pin":NSNull.null, @"state":[status isEqual:@"signed-out"] ? @"signedOut" : @"unavailable" };
    }
    if (!scope.length) {
        // Without an identity boundary, old rows cannot safely be shown as fallback.
        [cache invalidate];
        if (validated && ([status isEqual:@"ready"] || [status isEqual:@"empty"])) {
            if (now - receivedAt > cache.freshFor)
                return @{ @"rows":@[], @"pin":NSNull.null, @"state":@"unavailable" };
            NSDictionary *live = @{ @"rows":DPConversationRowsFromSnapshot(validated), @"pin":validated[@"pinned"] ?: NSNull.null };
            return DPConversationVisibleValue(live, NO, @"live");
        }
        return @{ @"rows":@[], @"pin":NSNull.null,
                  @"state":[status isEqual:@"signed-out"] ? @"signedOut" : @"unavailable" };
    }

    if (validated && ([status isEqual:@"ready"] || [status isEqual:@"empty"])) {
        NSArray *rows = DPConversationRowsFromSnapshot(validated);
        NSDictionary *stored = @{ @"rows":rows, @"pin":validated[@"pinned"] ?: NSNull.null };
        [cache observeValue:stored scope:scope receivedAt:receivedAt];
    } else {
        // Unknown scope is handled above. A known scope plus unavailable/malformed data
        // keeps its last good value but marks it stale through the shared cache policy.
        [cache observeValue:nil scope:scope receivedAt:receivedAt];
    }

    NSDictionary *value = [cache valueAtTime:now];
    if (!value) {
        return @{ @"rows":@[], @"pin":NSNull.null, @"state":@"unavailable" };
    }
    BOOL cached = ![cache isFreshAtTime:now];
    return DPConversationVisibleValue(value, cached, cached ? @"cached" : @"live");
}

void DPConversationSnapshotChanged(DPTabIntegrationPage *page) {
    if (page.snapshot) DPConversationPresentation(DPTabIntegrationCacheForPage(page), page.snapshot,
        page.integration, page.receivedAt, NSDate.timeIntervalSinceReferenceDate);
}

@implementation DPTabIntegrationConversationPreview
- (DPTabIntegrationListContent *)listContent {
    NSDictionary *data = DPConversationPresentation(self.context.cache, self.context.snapshot,
        self.integration, self.context.receivedAt, NSDate.timeIntervalSinceReferenceDate);
    NSArray<NSDictionary *> *rows = data[@"rows"];
    NSDictionary *pinned = data[@"pin"];
    NSString *state = data[@"state"] ?: @"unavailable";
    NSTimeInterval elapsed = NSDate.timeIntervalSinceReferenceDate - self.startedAt;
    if (!self.context.snapshot && !rows.count && [state isEqual:@"unavailable"] && elapsed < 6) state = @"loading";
    NSString *empty = DPTabIntegrationDefaultEmptyMessage(state, elapsed);
    __weak DPTabIntegrationConversationPreview *weakSelf = self;
    NSMutableArray<DPTabIntegrationItem *> *items = [NSMutableArray new];
    for (NSDictionary *row in rows) {
        NSString *identifier = row[@"id"];
        BOOL isPinned = [pinned isKindOfClass:NSDictionary.class] && [identifier isEqual:pinned[@"id"]];
        DPTabIntegrationItem *item = [[DPTabIntegrationItem alloc] initWithTitle:row[@"title"]];
        item.identifier = identifier;
        item.representedObject = row[@"url"];
        item.working = [row[@"activity"] isEqual:@"generating"];
        item.unread = [row[@"unread"] boolValue];
        item.pinned = isPinned;
        item.primaryAction = [[DPTabIntegrationAction alloc] initWithTitle:@"Open conversation" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *selected) {
            NSString *url = DPConversationURL(selected.representedObject, context.integration);
            if (url && DPTabIntegrationMatchesURL(context.integration, context.URLString)) [weakSelf navigateToURL:url];
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
    DPTabIntegrationListContent *content = [[DPTabIntegrationListContent alloc] initWithTitle:(self.providerTitle.length ? self.providerTitle : @"Conversations") items:items];
    content.state = state;
    content.emptyMessage = empty;
    content.statusText = [state isEqual:@"cached"] ? @"Cached" : nil;
    return content;
}
@end
