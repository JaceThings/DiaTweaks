#import "GroupTabs.h"
#import <objc/message.h>

static const NSInteger DPContentVisible = 2;  // content::Visibility: hidden, occluded, visible.

static long long DPVisibleSession(id browser) {
    long long found = 0;
    for (id contents in DPTrackedContents(browser)) {
        if (![contents respondsToSelector:@selector(visibility)]) return 0;
        if (((NSInteger (*)(id, SEL))objc_msgSend)(contents, @selector(visibility)) != DPContentVisible) continue;
        long long sid = DPSessionOf(contents);
        if (sid <= 0) continue;
        if (found) return 0;
        found = sid;
    }
    return found;
}

static id DPScriptWindow(NSWindow *window) {
    if (!window) return nil;
    for (id scripted in DPMsg(NSApp.delegate, @selector(appleScriptWindows)))
        if ([[scripted valueForKey:@"windowId"] isEqual:window.identifier]) return scripted;
    return nil;
}

long long DPActiveSession(id browser) {
    long long sid = DPVisibleSession(browser);
    if (sid > 0) return sid;
    id active = [DPScriptWindow(DPBrowserWindow(browser)) valueForKey:@"activeTab"];
    NSString *url = [active respondsToSelector:@selector(URL)] ? DPText(DPMsg(active, @selector(URL))) : nil;
    if (!url.length) return 0;
    long long found = 0;
    for (id contents in DPTrackedContents(browser)) {
        if (![DPText(DPMsg(contents, @selector(url))) isEqual:url]) continue;
        long long each = DPSessionOf(contents);
        if (each <= 0) continue;
        if (found) return 0;
        found = each;
    }
    return found;
}

static NSArray<NSDictionary *> *DPSiteGroups(NSArray *groups, id browser) {
    NSMutableDictionary<NSNumber *, NSString *> *hosts = [NSMutableDictionary dictionary];
    for (id contents in DPTrackedContents(browser)) {
        long long sid = DPSessionOf(contents);
        NSString *host = DPDomainKey(DPText(DPMsg(contents, @selector(url))));
        if (sid > 0 && host) hosts[@(sid)] = host;
    }
    NSMutableArray<NSDictionary *> *ops = [NSMutableArray array];
    for (id info in groups) {
        NSString *title = [info respondsToSelector:@selector(title)] ? DPText(DPMsg(info, @selector(title))) : nil;
        NSArray *raw = [info respondsToSelector:@selector(tabSessionIds)] ? DPMsg(info, @selector(tabSessionIds)) : nil;
        if (!title.length || ![raw isKindOfClass:NSArray.class]) continue;
        NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
        BOOL site = NO;
        for (id each in raw) {
            long long sid = DPLongID(each);
            if (sid <= 0) continue;
            [ids addObject:@(sid)];
            NSString *host = hosts[@(sid)];
            if (host && ([title isEqualToString:host] || [title isEqualToString:DPRegistrableDomain(host)] || [title isEqualToString:DPGroupTitle(host)]))
                site = YES;
        }
        if (site) [ops addObject:@{@"op": @"create", @"title": title, @"ids": ids}];
    }
    return ops;
}

static NSArray<NSDictionary *> *DPEveryGroup(NSArray *groups, id browser) {
    NSMutableArray<NSDictionary *> *ops = [NSMutableArray array];
    for (id info in groups) {
        NSString *title = [info respondsToSelector:@selector(title)] ? DPText(DPMsg(info, @selector(title))) : nil;
        NSArray *raw = [info respondsToSelector:@selector(tabSessionIds)] ? DPMsg(info, @selector(tabSessionIds)) : nil;
        if (![raw isKindOfClass:NSArray.class]) continue;
        NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
        for (id each in raw)
            if (DPLongID(each) > 0) [ids addObject:@(DPLongID(each))];
        if (ids.count) [ops addObject:title.length ? @{@"op": @"create", @"title": title, @"ids": ids} : @{@"op": @"create", @"ids": ids}];
    }
    return ops;
}

static void DPSeparateGroups(NSArray<NSDictionary *> *(^choose)(NSArray *groups, id browser)) {
    id browser = DPCommandBrowser();
    id delegate = browser ? DPGroupingDelegate(browser) : nil;
    if (![delegate respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]
        || ![delegate respondsToSelector:@selector(browser:removeTabsFromGroupWithSessionIds:completion:)])
        return;
    void (*ask)(id, SEL, id, void (^)(NSArray *)) = (void *)objc_msgSend;
    ask(delegate, @selector(browser:getAllTabGroupsWithCompletion:), browser, ^(NSArray *groups) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![groups isKindOfClass:NSArray.class]) return;
            NSArray<NSDictionary *> *ops = choose(groups, browser);
            NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
            for (NSDictionary *op in ops) [ids addObjectsFromArray:op[@"ids"]];
            if (!ids.count) return;
            void (*ungroup)(id, SEL, id, NSArray *, void (^)(id)) = (void *)objc_msgSend;
            ungroup(delegate, @selector(browser:removeTabsFromGroupWithSessionIds:completion:), browser, ids, ^(id _) {
                dispatch_async(dispatch_get_main_queue(), ^{ DPOfferRegroup(delegate, browser, ops); });
            });
        });
    });
}

void DPSeparateDomain(void) {
    long long active = DPActiveSession(DPCommandBrowser());
    if (active <= 0) return;
    DPSeparateGroups(^NSArray<NSDictionary *> *(NSArray *groups, id browser) {
        for (NSDictionary *op in DPSiteGroups(groups, browser))
            if ([op[@"ids"] containsObject:@(active)]) return @[ op ];
        return @[];
    });
}

void DPSeparateAllGroups(void) { DPSeparateGroups(^NSArray<NSDictionary *> *(NSArray *groups, id browser) { return DPEveryGroup(groups, browser); }); }
