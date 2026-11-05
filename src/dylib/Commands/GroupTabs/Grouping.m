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
    // No title leaves the group for Dia to name, as Tidy Tabs does.
    if (title.length && [props respondsToSelector:@selector(setTitle:)]) [props setTitle:title];
    return props;
}

// Cleared by the next key press, so Command-Z only undoes a grouping right after it.
static void (^DPUndoGrouping)(void);

@interface DPGroupUndo : NSObject
@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) id browser;
@property (nonatomic, copy) NSArray *ids;
@property (nonatomic, copy) NSDictionary *places;
@end
@implementation DPGroupUndo
@end

static void DPInstallUndoKey(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
            void (^undo)(void) = DPUndoGrouping;
            DPUndoGrouping = nil;
            NSEventModifierFlags mods = event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl);
            if (!undo || mods != NSEventModifierFlagCommand || ![event.charactersIgnoringModifiers isEqualToString:@"z"]) return event;
            undo();
            return nil;
        }];
    });
}

static void DPUngroup(id delegate, id browser, NSArray *ids, NSDictionary *places, void (^done)(void)) {
    void (^finish)(void) = ^{};
    if (done) finish = done;
    if (!delegate || !browser || !ids.count) return finish();
    void (*ungroup)(id, SEL, id, NSArray *, void (^)(id)) = (void *)objc_msgSend;
    ungroup(delegate, @selector(browser:removeTabsFromGroupWithSessionIds:completion:), browser, ids, ^(id _) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!places.count) return finish();
            DPRestorePlaces(delegate, browser, places, finish);
        });
    });
}

void DPOfferUndo(id delegate, id browser, NSArray *ids, NSDictionary *places) {
    DPInstallUndoKey();
    __weak id weakDelegate = delegate, weakBrowser = browser;
    DPUndoGrouping = ^{ DPUngroup(weakDelegate, weakBrowser, ids, places, nil); };
}

// Windows undo one after another, so each is put back before the next is touched.
static void DPUndoAt(NSArray<DPGroupUndo *> *entries, NSUInteger index) {
    if (index >= entries.count) return;
    DPGroupUndo *entry = entries[index];
    DPUngroup(entry.delegate, entry.browser, entry.ids, entry.places, ^{ DPUndoAt(entries, index + 1); });
}

static void DPOfferUndoMany(NSArray<DPGroupUndo *> *entries) {
    DPInstallUndoKey();
    NSArray *held = [entries copy];
    DPUndoGrouping = ^{ DPUndoAt(held, 0); };
}

void DPRunOps(id delegate, id browser, NSArray<NSDictionary *> *ops, NSUInteger index, void (^done)(void)) {
    if (index >= ops.count) return done();
    NSDictionary *op = ops[index];
    void (^next)(id) = ^(id result) {
        dispatch_async(dispatch_get_main_queue(), ^{ DPRunOps(delegate, browser, ops, index + 1, done); });
    };
    void (*create)(id, SEL, id, NSArray *, id, void (^)(id)) = (void *)objc_msgSend;
    void (*add)(id, SEL, id, NSString *, NSArray *, void (^)(id)) = (void *)objc_msgSend;
    if ([op[@"op"] isEqual:@"create"]) {
        id props = DPGroupProperties(op[@"title"]);
        if (!props) return DPRunOps(delegate, browser, ops, index + 1, done);
        create(delegate, @selector(browser:createTabGroupWithSessionIds:properties:completion:), browser, op[@"ids"], props, next);
    } else {
        add(delegate, @selector(browser:addTabsToGroupWithId:sessionIds:completion:), browser, op[@"group"], op[@"ids"], next);
    }
}

static void DPGroupBrowser(id browser, BOOL scoped, void (^done)(id delegate, NSArray *ids, NSDictionary *places)) {
    if (!done) return;
    void (^finish)(id, NSArray *, NSDictionary *) = done;
    id delegate = DPGroupingDelegate(browser);
    if (![delegate respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]) return finish(nil, nil, nil);
    NSMutableSet<NSNumber *> *pinnedSessions = [NSMutableSet set];
    NSMutableSet<NSString *> *pinnedURLs = [NSMutableSet set], *openURLs = [NSMutableSet set];
    DPCollectPinned(pinnedSessions, pinnedURLs, openURLs);
    NSMutableArray<NSDictionary *> *tabs = [NSMutableArray array];
    for (id contents in DPTrackedContents(browser)) {
        long long sid = DPSessionOf(contents);
        NSString *url = DPText(DPMsg(contents, @selector(url)));
        NSString *domain = DPDomainKey(url);
        if (sid <= 0 || !domain || DPPinned(sid, url, pinnedSessions, pinnedURLs, openURLs)) continue;
        [tabs addObject:@{@"session": @(sid), @"domain": domain, @"url": url}];
    }
    void (*ask)(id, SEL, id, void (^)(NSArray *)) = (void *)objc_msgSend;
    NSArray *snapshot = [tabs copy];
    ask(delegate, @selector(browser:getAllTabGroupsWithCompletion:), browser, ^(NSArray *groups) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![groups isKindOfClass:NSArray.class]) return finish(nil, nil, nil);
            NSArray *ops = DPOps(snapshot, groups);
            NSArray *ids = [ops valueForKeyPath:@"@unionOfArrays.ids"];
            if (!ids.count) return finish(nil, nil, nil);
            NSMutableDictionary *urls = [NSMutableDictionary new];
            for (NSDictionary *tab in snapshot) if ([ids containsObject:tab[@"session"]]) urls[tab[@"session"]] = tab[@"url"];
            NSWindow *window = DPBrowserWindow(browser);
            NSDictionary *places = scoped ? DPTabPlacesInWindow(window, urls) : DPTabPlaces(urls);
            DPRunOps(delegate, browser, ops, 0, ^{ finish(delegate, ids, places); });
        });
    });
}

void DPGroupTabsOnce(void) {
    id browser = DPCommandBrowser();
    if (!browser) return;
    DPGroupBrowser(browser, NO, ^(id delegate, NSArray *ids, NSDictionary *places) {
        if (ids.count) DPOfferUndo(delegate, browser, ids, places);
    });
}

static void DPGroupNext(NSArray *browsers, NSUInteger index, NSMutableArray<DPGroupUndo *> *entries) {
    if (index >= browsers.count) {
        if (entries.count) DPOfferUndoMany(entries);
        return;
    }
    id browser = browsers[index];
    DPGroupBrowser(browser, YES, ^(id delegate, NSArray *ids, NSDictionary *places) {
        if (ids.count) {
            DPGroupUndo *entry = [DPGroupUndo new];
            entry.delegate = delegate;
            entry.browser = browser;
            entry.ids = ids;
            entry.places = places;
            [entries addObject:entry];
        }
        DPGroupNext(browsers, index + 1, entries);
    });
}

void DPGroupTabsAllWindows(void) {
    NSArray *browsers = [DPCommandBrowsers() copy];
    if (!browsers.count) return;
    DPGroupNext(browsers, 0, [NSMutableArray array]);
}
