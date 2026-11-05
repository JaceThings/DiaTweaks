// Ungroup This Domain takes apart the site group the current tab is in, and Ungroup All Domains every site group in the
// window. Dia's ungroup leaves the tabs open; Close this Group would close them, and the browser delegate has no call for
// that. Command-Z groups them again.
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

// The visible page, or the front window's active tab when a split shows more than one page. Nothing when that tab's
// address is open in another tab too, since then it can't be told apart.
static long long DPActiveSession(id browser) {
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

// A site group is one Group Tabs by Domain could have made: its title is the host or site of one of its tabs here, or
// that site's name. A create op for each, so undo can make them again.
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

// Ungroups every tab in the chosen site groups, then offers Command-Z to make those groups again.
static void DPUngroupSiteGroups(NSArray<NSDictionary *> *(^choose)(NSArray<NSDictionary *> *sites)) {
    id browser = DPCommandBrowser();
    id delegate = browser ? DPGroupingDelegate(browser) : nil;
    if (![delegate respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]
        || ![delegate respondsToSelector:@selector(browser:removeTabsFromGroupWithSessionIds:completion:)])
        return;
    void (*ask)(id, SEL, id, void (^)(NSArray *)) = (void *)objc_msgSend;
    ask(delegate, @selector(browser:getAllTabGroupsWithCompletion:), browser, ^(NSArray *groups) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![groups isKindOfClass:NSArray.class]) return;
            NSArray<NSDictionary *> *ops = choose(DPSiteGroups(groups, browser));
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

void DPUngroupDomain(void) {
    long long active = DPActiveSession(DPCommandBrowser());
    if (active <= 0) return;
    DPUngroupSiteGroups(^NSArray<NSDictionary *> *(NSArray<NSDictionary *> *sites) {
        for (NSDictionary *op in sites)
            if ([op[@"ids"] containsObject:@(active)]) return @[ op ];
        return @[];
    });
}

// Ungroup All Domains takes apart every site group in the front window. Groups with other names stay.
void DPUngroupAllDomains(void) {
    DPUngroupSiteGroups(^NSArray<NSDictionary *> *(NSArray<NSDictionary *> *sites) { return sites; });
}
