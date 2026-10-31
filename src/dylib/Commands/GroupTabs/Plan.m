#import "GroupTabs.h"

static NSString *DPDecodeLabel(NSString *label) {
    if (![label hasPrefix:@"xn--"]) return label;
    NSString *decoded = [label stringByApplyingTransform:@"Any-Punycode" reverse:YES];
    return decoded.length && ![decoded isEqualToString:label] ? decoded.lowercaseString : label;
}

// nil for the new tab page, dia://, chrome://, file and other internal pages.
NSString *DPDomainKey(NSString *urlString) {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return nil;
    NSString *host = url.host.lowercaseString;
    if (!host.length) return nil;
    while ([host hasSuffix:@"."]) host = [host substringToIndex:host.length - 1];
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    for (NSString *part in [host componentsSeparatedByString:@"."]) [labels addObject:DPDecodeLabel(part)];
    host = [labels componentsJoinedByString:@"."];
    if ([host hasPrefix:@"www."] && host.length > 4) host = [host substringFromIndex:4];
    return host.length ? host : nil;
}

// Loose tabs join an existing group whose title is exactly the domain. Tabs in any other group stay put.
NSArray<NSDictionary *> *DPOps(NSArray<NSDictionary *> *tabs, NSArray *groups) {
    NSMutableDictionary<NSNumber *, NSString *> *groupTitle = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *homeID = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSMutableSet<NSNumber *> *> *homeMembers = [NSMutableDictionary dictionary];
    for (id info in groups) {
        if (![info respondsToSelector:@selector(groupId)]) continue;
        NSString *groupID = DPText(DPMsg(info, @selector(groupId)));
        NSString *title = [info respondsToSelector:@selector(title)] ? DPText(DPMsg(info, @selector(title))) ?: @"" : @"";
        if (!groupID.length) continue;
        NSArray *rawIDs = [info respondsToSelector:@selector(tabSessionIds)] ? DPMsg(info, @selector(tabSessionIds)) : nil;
        if ([rawIDs isKindOfClass:NSArray.class]) for (id raw in rawIDs) {
            long long sid = DPLongID(raw);
            if (sid > 0) groupTitle[@(sid)] = title;
        }
        if (title.length && !homeID[title]) {
            homeID[title] = groupID;
            homeMembers[title] = [NSMutableSet set];
        }
        if (homeMembers[title]) {
            if ([rawIDs isKindOfClass:NSArray.class]) for (id raw in rawIDs) {
                long long sid = DPLongID(raw);
                if (sid > 0) [homeMembers[title] addObject:@(sid)];
            }
        }
    }
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *pools = [NSMutableDictionary dictionary];
    for (NSDictionary *tab in tabs) {
        NSNumber *sid = tab[@"session"];
        NSString *domain = tab[@"domain"];
        NSString *title = groupTitle[sid];
        if (title && ![title isEqualToString:domain]) continue;
        NSMutableArray *pool = pools[domain] ?: (pools[domain] = [NSMutableArray array]);
        [pool addObject:tab];
    }
    NSMutableArray<NSDictionary *> *ops = [NSMutableArray array];
    for (NSString *domain in pools) {
        NSArray<NSDictionary *> *pool = pools[domain];
        if (pool.count < 2) continue;
        NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
        for (NSDictionary *tab in pool) if (![homeMembers[domain] containsObject:tab[@"session"]]) [ids addObject:tab[@"session"]];
        if (!ids.count) continue;
        if (homeID[domain]) [ops addObject:@{@"op": @"add", @"group": homeID[domain], @"ids": ids}];
        else if (ids.count >= 2) [ops addObject:@{@"op": @"create", @"title": domain, @"ids": ids}];
    }
    return ops;
}
