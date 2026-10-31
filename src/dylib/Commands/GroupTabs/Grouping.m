#import "GroupTabs.h"
#import <objc/message.h>

static void DPCollectPinned(NSMutableSet<NSNumber *> *sessions, NSMutableSet<NSString *> *pinnedURLs, NSMutableSet<NSString *> *openURLs) {
    id app = NSApp.delegate;
    if (![app respondsToSelector:@selector(appleScriptWindows)]) return;
    NSArray *windows = DPMsg(app, @selector(appleScriptWindows));
    if (![windows isKindOfClass:NSArray.class]) return;
    for (id window in windows) {
        if (![window respondsToSelector:@selector(appleScriptTabs)]) continue;
        NSArray *tabs = DPMsg(window, @selector(appleScriptTabs));
        if (![tabs isKindOfClass:NSArray.class]) continue;
        for (id tab in tabs) {
            NSString *url = [tab respondsToSelector:@selector(URL)] ? DPText(DPMsg(tab, @selector(URL))) : nil;
            BOOL pinned = [tab respondsToSelector:@selector(isPinned)] && DPMsgBool(tab, @selector(isPinned));
            id rawID = [tab respondsToSelector:@selector(tabId)] ? DPMsg(tab, @selector(tabId)) : nil;
            if (pinned && url.length) [pinnedURLs addObject:url];
            else if (url.length) [openURLs addObject:url];
            if (!pinned) continue;
            long long sid = DPLongID(rawID);
            if (sid > 0) [sessions addObject:@(sid)];
        }
    }
}

static BOOL DPPinned(long long sid, NSString *url, NSSet<NSNumber *> *sessions, NSSet<NSString *> *urls, NSSet<NSString *> *openURLs) {
    if ([sessions containsObject:@(sid)]) return YES;
    return url.length && [urls containsObject:url] && ![openURLs containsObject:url];
}

static id DPGroupProperties(NSString *title) {
    Class cls = objc_getClass(DPDiaTabGroupProperties);
    id props = cls ? [cls new] : nil;
    if ([props respondsToSelector:@selector(setTitle:)]) [props setTitle:title];
    return props;
}

static void DPRunOps(id delegate, id browser, NSArray<NSDictionary *> *ops, NSUInteger index) {
    if (index >= ops.count) return;
    NSDictionary *op = ops[index];
    void (^next)(id) = ^(id result) {
        dispatch_async(dispatch_get_main_queue(), ^{ DPRunOps(delegate, browser, ops, index + 1); });
    };
    void (*create)(id, SEL, id, NSArray *, id, void (^)(id)) = (void *)objc_msgSend;
    void (*add)(id, SEL, id, NSString *, NSArray *, void (^)(id)) = (void *)objc_msgSend;
    if ([op[@"op"] isEqual:@"create"]) {
        id props = DPGroupProperties(op[@"title"]);
        if (!props) return DPRunOps(delegate, browser, ops, index + 1);
        create(delegate, @selector(browser:createTabGroupWithSessionIds:properties:completion:), browser, op[@"ids"], props, next);
    } else {
        add(delegate, @selector(browser:addTabsToGroupWithId:sessionIds:completion:), browser, op[@"group"], op[@"ids"], next);
    }
}

void DPGroupTabsOnce(void) {
    id browser = DPCommandBrowser();
    if (!browser) return;
    id delegate = DPGroupingDelegate(browser);
    if (![delegate respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]) return;
    NSMutableSet<NSNumber *> *pinnedSessions = [NSMutableSet set];
    NSMutableSet<NSString *> *pinnedURLs = [NSMutableSet set], *openURLs = [NSMutableSet set];
    DPCollectPinned(pinnedSessions, pinnedURLs, openURLs);
    NSMutableArray<NSDictionary *> *tabs = [NSMutableArray array];
    for (id contents in DPTrackedContents(browser)) {
        long long sid = DPSessionOf(contents);
        NSString *url = DPText(DPMsg(contents, @selector(url)));
        NSString *domain = DPDomainKey(url);
        if (sid <= 0 || !domain || DPPinned(sid, url, pinnedSessions, pinnedURLs, openURLs)) continue;
        [tabs addObject:@{@"session": @(sid), @"domain": domain}];
    }
    void (*ask)(id, SEL, id, void (^)(NSArray *)) = (void *)objc_msgSend;
    NSArray *snapshot = [tabs copy];
    ask(delegate, @selector(browser:getAllTabGroupsWithCompletion:), browser, ^(NSArray *groups) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![groups isKindOfClass:NSArray.class]) return;
            NSArray *ops = DPOps(snapshot, groups);
            DPRunOps(delegate, browser, ops, 0);
        });
    });
}
