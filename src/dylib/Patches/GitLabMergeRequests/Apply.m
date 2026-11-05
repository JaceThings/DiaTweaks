#import "GitLabMergeRequests.h"
#import <objc/message.h>

// What a plan changes in a folder, through Dia's own ways of changing it.

static void DPGitLabAddToFolder(DPGitLabFolder *folder, NSArray<NSNumber *> *sessions) {
    if (!sessions.count) return;
    void (*add)(id, SEL, id, NSString *, NSArray *, void (^)(id)) = (void *)objc_msgSend;
    add(DPGroupingDelegate(folder.browser), @selector(browser:addTabsToGroupWithId:sessionIds:completion:), folder.browser,
        folder.groupID, sessions, ^(id result) {});
}

// A loaded tab closes as the user would close it. One Dia hasn't loaded since launch isn't among its scripting tabs, and
// leaves the tab store directly; on a Dia where that closure has changed, it stays until a refresh finds it loaded.
static void DPGitLabClose(DPGitLabFolder *folder, NSArray<NSString *> *tabIDs) {
    NSString *active = DPGitLabActiveTab(folder);
    NSMutableArray *unloaded = [NSMutableArray new];
    for (NSString *tabID in tabIDs) {
        if ([tabID isEqual:active]) continue;
        id scriptTab = DPGitLabScriptTab(folder, tabID);
        if ([scriptTab respondsToSelector:@selector(close:)]) ((void (*)(id, SEL, id))objc_msgSend)(scriptTab, @selector(close:), nil);
        else [unloaded addObject:tabID];
    }
    if (unloaded.count) DPGitLabRemoveTabs(NSApp.delegate, folder.groupID, unloaded);
}

// A loose tab moves by its session, which only a loaded tab has.
static void DPGitLabMove(DPGitLabFolder *folder, NSArray<NSString *> *tabIDs) {
    NSDictionary *sessions = DPGitLabSessionsByURL(folder.browser);
    NSMutableArray *move = [NSMutableArray new];
    for (NSString *tabID in tabIDs) {
        NSNumber *session = sessions[DPText(DPMsg(DPGitLabScriptTab(folder, tabID), @selector(URL))) ?: @""];
        if (session) [move addObject:session];
    }
    DPGitLabAddToFolder(folder, move);
}

// Moves the tabs just opened into the folder once Dia has made their web contents and so their sessions. Only sessions
// on those merge requests: a tab the user opens meanwhile stays where it is.
static void DPGitLabAddWhenLoaded(DPGitLabFolder *folder, NSSet *known, NSSet<NSString *> *keys, NSArray *hosts, int tries, void (^done)(void)) {
    NSMutableArray *fresh = [NSMutableArray new];
    NSDictionary *byURL = DPGitLabSessionsByURL(folder.browser);
    for (NSString *url in byURL)
        if (![known containsObject:byURL[url]] && [keys containsObject:DPGitLabMRKey(url, hosts) ?: @""]) [fresh addObject:byURL[url]];
    if (fresh.count < keys.count && tries > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(),
                       ^{ DPGitLabAddWhenLoaded(folder, known, keys, hosts, tries - 1, done); });
        return;
    }
    DPGitLabAddToFolder(folder, fresh);
    done();
}

// Where Dia's createTab can't be used: a loose tab in the folder's window, as AppleScript's make opens one, moved in after.
static void DPGitLabOpenLoose(DPGitLabFolder *folder, NSArray<DPGitLabMR *> *mrs, void (^done)(void)) {
    id window = folder.scriptWindow;
    Class tabClass = objc_getClass(DPDiaScriptTab);
    SEL make = @selector(newScriptingObjectOfClass:forValueForKey:withContentsValue:properties:);
    if (!mrs.count || !tabClass || ![window respondsToSelector:make] || ![window respondsToSelector:@selector(insertValue:inPropertyWithKey:)]) return done();
    NSSet *known = [NSSet setWithArray:DPGitLabSessionsByURL(folder.browser).allValues];
    NSMutableSet *keys = [NSMutableSet new], *hosts = [NSMutableSet new];
    id (*newObject)(id, SEL, Class, NSString *, id, NSDictionary *) = (void *)objc_msgSend;
    for (DPGitLabMR *mr in mrs) {
        id tab = newObject(window, make, tabClass, @"appleScriptTabs", nil, @{@"URL" : mr.url});
        if (tab) [window insertValue:tab inPropertyWithKey:@"appleScriptTabs"];
        [keys addObject:mr.key];
        [hosts addObject:DPGitLabURLHost(mr.url) ?: @""];
    }
    DPGitLabAddWhenLoaded(folder, known, keys, hosts.allObjects, 20, done);
}

void DPGitLabApply(DPGitLabFolder *folder, DPGitLabPlan *plan, void (^done)(void)) {
    DPGitLabClose(folder, plan.closes);
    DPGitLabMove(folder, plan.moves);
    NSMutableArray *loose = [NSMutableArray new];
    for (DPGitLabMR *mr in plan.inserts)
        if (!DPGitLabCreateTabInGroup(NSApp.delegate, folder.groupID, mr.url, mr.title ?: mr.url)) [loose addObject:mr];
    DPGitLabOpenLoose(folder, loose, done);
}
