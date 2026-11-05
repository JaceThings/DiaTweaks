// Group Selected Tabs by Domain. allSelectedTabIDs is the selection; with none, the active tab alone counts as one.
// Empty or a single tab does nothing, the same as the full-window command and Tidy Tabs, which never group one tab.
#import "GroupTabs.h"

@interface NSObject (DPSelectionFields)
- (id)safeSwiftValueForKey:(NSString *)key;
@end

NSArray<NSString *> *DPSelectionIDKeys(id selection);
NSString *DPIDKey(id value);
void DPEachValue(id collection, void (^visit)(id value));

// Dia's Swift classes show demangled names, like Window.PlatformWindow, and its KVO subclasses don't match "_Tt" either.
static id DPField(id obj, NSString *key) {
    if (![obj respondsToSelector:@selector(safeSwiftValueForKey:)]) return nil;
    return [obj safeSwiftValueForKey:key];
}

static NSArray<NSString *> *DPWalkKeys(void) {
    static NSArray<NSString *> *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @[ @"contentViewController", @"tabSidebarViewController", @"tabStripContainerViewController", @"delegate", @"viewModel",
                  @"presenter", @"sidebarStorage", @"storage", @"sidebarControllerStorage", @"controllerStorage", @"tabListController",
                  @"tabStripController" ];
    });
    return keys;
}

static BOOL DPIsTabList(id obj) {
    const char *name = object_getClassName(obj);
    return name && (strstr(name, "TabListController") || strstr(name, "TabStripController"));
}

// Only the window, sidebar and tab objects. A key such as delegate can point at the rest of the app.
static BOOL DPMayHoldTabs(id obj) {
    const char *name = object_getClassName(obj);
    return name && (strstr(name, "Tab") || strstr(name, "Window") || strstr(name, "Sidebar") || strstr(name, "Strip"));
}

static void DPWalk(id obj, NSMutableArray *found, NSMutableSet *seen, NSInteger depth) {
    if (!obj || depth > 8 || [seen containsObject:obj]) return;
    if ([obj isKindOfClass:NSArray.class]) {
        for (id each in obj) DPWalk(each, found, seen, depth + 1);
        return;
    }
    if ([obj isKindOfClass:NSDictionary.class]) {
        for (id each in [obj allValues]) DPWalk(each, found, seen, depth + 1);
        return;
    }
    [seen addObject:obj];
    if (DPIsTabList(obj)) [found addObject:obj];
    if ([obj isKindOfClass:NSWindow.class]) DPWalk([(NSWindow *)obj contentViewController], found, seen, depth + 1);
    if ([obj isKindOfClass:NSViewController.class] && [obj respondsToSelector:@selector(childViewControllers)])
        DPWalk([(NSViewController *)obj childViewControllers], found, seen, depth + 1);
    if (!DPMayHoldTabs(obj)) return;
    for (NSString *key in DPWalkKeys()) DPWalk(DPField(obj, key), found, seen, depth + 1);
}

static void DPAddURL(NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *urls, NSString *key, NSString *url) {
    if (!key.length || !url.length) return;
    NSMutableArray *list = urls[key] ?: [NSMutableArray array];
    if (![list containsObject:url]) [list addObject:url];
    urls[key] = list;
}

static void DPAddSession(NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *sessions, NSString *key, NSNumber *sid) {
    if (!key.length || !sid) return;
    NSMutableArray *list = sessions[key] ?: [NSMutableArray array];
    if (![list containsObject:sid]) [list addObject:sid];
    sessions[key] = list;
}

static void DPReadObject(id obj, NSString *key, NSSet<NSNumber *> *tracked,
                         NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *sessions,
                         NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *urls) {
    if (!obj || obj == NSNull.null || !key.length) return;
    long long sid = DPLongID(DPField(obj, @"tabSessionID"));
    if (sid <= 0) sid = DPLongID(DPField(obj, @"sessionId"));
    if (sid > 0 && [tracked containsObject:@(sid)]) DPAddSession(sessions, key, @(sid));
    DPAddURL(urls, key, DPText(DPField(obj, @"webContentURL")) ?: DPText(DPField(obj, @"url")));
}

static void DPReadContent(id content, NSString *key, NSSet<NSNumber *> *tracked,
                          NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *sessions,
                          NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *urls) {
    id model = DPField(content, @"viewModel");
    for (id obj in @[ content ?: NSNull.null, DPField(content, @"delegate") ?: NSNull.null, DPField(content, @"webContent") ?: NSNull.null,
                      model ?: NSNull.null, DPField(model, @"delegate") ?: NSNull.null ])
        DPReadObject(obj, key, tracked, sessions, urls);
}

static void DPReadTab(id tab, NSSet<NSNumber *> *tracked, NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *sessions,
                      NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *urls) {
    NSString *key = DPIDKey(DPField(tab, @"tabID") ?: DPField(DPField(tab, @"viewModel"), @"tabID"));
    if (!key.length) return;
    DPReadContent(tab, key, tracked, sessions, urls);
    DPEachValue(DPField(tab, @"contentControllers") ?: DPField(tab, @"contentViews"), ^(id content) {
        DPReadContent(content, key, tracked, sessions, urls);
    });
}

static id DPSelection(NSWindow *window, NSArray *controllers) {
    id state = DPField(DPField(DPField(window, @"viewModel"), @"stateSubject"), @"currentValue");
    id selection = DPField(state, @"tabSelectionState");
    if (selection) return selection;
    for (id controller in controllers) {
        selection = DPField(controller, @"selectionState") ?: DPField(controller, @"tabSelectionState") ?: DPField(controller, @"sidebarSelectionState");
        if (selection) return selection;
    }
    return nil;
}

NSSet<NSNumber *> *DPSelectedSessions(id browser) {
    NSWindow *window = DPBrowserWindow(browser);
    if (!window) return nil;
    NSMutableArray *controllers = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    DPWalk(window, controllers, seen, 0);
    for (NSView *view in [DPFindViews(DPDiaTabList) arrayByAddingObjectsFromArray:DPFindViews(DPDiaTabStrip)])
        if (view.window == window) DPWalk(DPField(DPField(view, @"viewModel"), @"presenter"), controllers, seen, 0);
    NSArray<NSString *> *keys = DPSelectionIDKeys(DPSelection(window, controllers));
    if (keys.count < 2) return nil;

    NSMutableSet<NSNumber *> *tracked = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *byURL = [NSMutableDictionary dictionary];
    for (id contents in DPTrackedContents(browser)) {
        long long sid = DPSessionOf(contents);
        NSString *url = DPText(DPMsg(contents, @selector(url)));
        if (sid <= 0) continue;
        [tracked addObject:@(sid)];
        if (!url.length) continue;
        NSMutableArray *list = byURL[url] ?: [NSMutableArray array];
        [list addObject:@(sid)];
        byURL[url] = list;
    }
    NSMutableDictionary *sessions = [NSMutableDictionary dictionary], *urls = [NSMutableDictionary dictionary];
    for (id controller in controllers) DPEachValue(DPField(controller, @"tabControllers"), ^(id tab) { DPReadTab(tab, tracked, sessions, urls); });
    for (NSView *tab in [DPFindViews(DPDiaTabView) arrayByAddingObjectsFromArray:DPFindViews(DPDiaPinnedTab)])
        if (tab.window == window) DPReadTab(tab, tracked, sessions, urls);

    NSMutableSet<NSNumber *> *chosen = [NSMutableSet set];
    for (NSString *key in keys) {
        if ([sessions[key] count]) {
            [chosen addObjectsFromArray:sessions[key]];
            continue;
        }
        for (NSString *url in urls[key]) {
            NSMutableArray<NSNumber *> *list = byURL[url];
            if (!list.count) continue;
            [chosen addObject:list.firstObject];
            [list removeObjectAtIndex:0];
        }
    }
    return chosen.count >= 2 ? [chosen copy] : nil;
}
