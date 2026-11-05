#import "GitLabMergeRequests.h"
#import <objc/message.h>

@implementation DPGitLabFolder
@end

void DPGitLabLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSLog(@"DiaPatches: GitLab merge requests: %@", [[NSString alloc] initWithFormat:format arguments:args]);
    va_end(args);
}

static NSArray *DPGitLabScriptWindows(void) {
    NSArray *windows = DPMsg(NSApp.delegate, @selector(appleScriptWindows));  // Front to back.
    return [windows isKindOfClass:NSArray.class] ? windows : @[];
}

static NSString *DPGitLabSpaceOfWindow(id scriptWindow) {
    return DPGitLabEval(DPGitLabEvalObject(scriptWindow, @"@activeProfile"), @"spaceID.rawValue");
}

// The frontmost window that shows a Space: a private window in front has none.
NSString *DPGitLabFrontSpace(NSString **name) {
    for (id window in DPGitLabScriptWindows()) {
        id profile = DPGitLabEvalObject(window, @"@activeProfile");
        NSString *space = DPGitLabEval(profile, @"spaceID.rawValue");
        if (!space) continue;
        if (name) *name = DPGitLabEval(profile, @"profileName");
        return space;
    }
    return nil;
}

static NSArray *DPGitLabScriptTabs(id scriptWindow) {
    NSArray *tabs = [scriptWindow respondsToSelector:@selector(appleScriptTabs)] ? DPMsg(scriptWindow, @selector(appleScriptTabs)) : nil;
    return [tabs isKindOfClass:NSArray.class] ? tabs : @[];
}

static NSString *DPGitLabTabID(id scriptTab) {
    return [scriptTab respondsToSelector:@selector(tabId)] ? DPText(DPMsg(scriptTab, @selector(tabId))) : nil;
}

id DPGitLabScriptTab(DPGitLabFolder *folder, NSString *tabID) {
    for (id scriptTab in DPGitLabScriptTabs(folder.scriptWindow)) if ([DPGitLabTabID(scriptTab) isEqual:tabID]) return scriptTab;
    return nil;
}

NSString *DPGitLabActiveTab(DPGitLabFolder *folder) { return DPGitLabEval(folder.scriptWindow, @"activeTabIdentifier"); }

NSDictionary<NSString *, NSNumber *> *DPGitLabSessionsByURL(id browser) {
    NSMutableDictionary *sessions = [NSMutableDictionary new];
    for (id contents in DPTrackedContents(browser)) {
        NSString *url = DPText(DPMsg(contents, @selector(url)));
        long long session = DPSessionOf(contents);
        if (url && session > 0) sessions[url] = @(session);
    }
    return sessions;
}

// Which Live Folders are Pull Requests folders comes from Dia's own configuration: their titles are the user's to change.
// Each one's Space comes from the tab store, then the window showing that Space and the window's browser, so a refresh
// finds the folder whether the sidebar is open, hidden or replaced by tabs at the top.
NSArray<DPGitLabFolder *> *DPGitLabFolders(void) {
    NSMutableDictionary<NSString *, DPGitLabFolder *> *bySpace = [NSMutableDictionary new];
    for (NSString *group in DPGitLabPullRequestFolderIDs(NSApp.delegate)) {
        DPGitLabFolder *folder = [DPGitLabFolder new];
        folder.groupID = group;
        folder.space = DPGitLabGroupSpace(NSApp.delegate, group);
        for (id window in DPGitLabScriptWindows())
            if (folder.space && [DPGitLabSpaceOfWindow(window) isEqual:folder.space]) {
                folder.scriptWindow = window;
                break;
            }
        NSString *windowID = DPGitLabEval(folder.scriptWindow, @"windowID.rawValue") ?: DPGitLabEval(folder.scriptWindow, @"windowID");
        for (NSWindow *window in NSApp.windows)
            if (windowID && DPIsKind(window, DPDiaWindow) && [DPGitLabEval(window, @"viewModel.browserID.windowID.rawValue") isEqual:windowID])
                folder.browser = DPBrowserOfWindow(window);
        if (folder.space && folder.scriptWindow && folder.browser) bySpace[folder.space] = folder;
        else if (!folder.space || folder.scriptWindow) DPGitLabLog(@"can't place folder %@: Space %@, browser %@", group, folder.space, folder.browser);
        // A Space with no window open has nothing to show its folder in: it waits for one.
    }
    return bySpace.allValues;
}

NSArray<DPGitLabTab *> *DPGitLabTabsOf(DPGitLabFolder *folder, NSString *host) {
    NSArray<NSArray<NSString *> *> *members = DPGitLabGroupMembers(NSApp.delegate, folder.groupID);
    if (!members) return nil;
    NSArray *hosts = host ? @[host] : @[];
    NSString *active = DPGitLabActiveTab(folder);
    NSMutableArray *tabs = [NSMutableArray new];
    NSMutableSet *inFolder = [NSMutableSet new];
    for (NSArray<NSString *> *member in members) {
        [inFolder addObject:member[0]];
        NSString *key = DPGitLabMRKey(member[1], hosts);
        if (key) [tabs addObject:[DPGitLabTab key:key tab:member[0] inFolder:YES selected:[active isEqual:member[0]]]];
    }
    // Loose tabs on the same merge requests, which a refresh moves in rather than opening twice.
    for (id scriptTab in DPGitLabScriptTabs(folder.scriptWindow)) {
        NSString *key = DPGitLabMRKey(DPText(DPMsg(scriptTab, @selector(URL))), hosts), *tabID = DPGitLabTabID(scriptTab);
        if (key && tabID && ![inFolder containsObject:tabID])
            [tabs addObject:[DPGitLabTab key:key tab:tabID inFolder:NO selected:[active isEqual:tabID]]];
    }
    return tabs;
}
