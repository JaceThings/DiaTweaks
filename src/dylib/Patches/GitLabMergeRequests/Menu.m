#import "GitLabMergeRequests.h"

// A GitLab item in the folder's Pull Requests submenu, after Dia's GitHub and Bitbucket, and Dia's Refresh and bucket switches
// reaching GitLab too.
static const NSInteger DPGitLabMenuTag = 0xD1A7006;
static NSString *DPGitLabMenuSpace;  // The Space of the folder row last right-clicked.

static NSMenuItem *DPGitLabItemTitled(NSMenu *menu, NSString *title) {
    for (NSMenuItem *item in menu.itemArray) if ([item.title isEqualToString:title]) return item;
    return nil;
}

static BOOL DPGitLabIsPullRequestsMenu(NSMenu *menu) {
    return DPGitLabItemTitled(menu, @"GitHub") && DPGitLabItemTitled(menu, @"Bitbucket") && DPGitLabItemTitled(menu, @"Refresh");
}

static NSMenu *DPGitLabFindPullRequestsMenu(NSMenu *menu) {
    if (DPGitLabIsPullRequestsMenu(menu)) return menu;
    for (NSMenuItem *item in menu.itemArray) {
        NSMenu *found = item.submenu ? DPGitLabFindPullRequestsMenu(item.submenu) : nil;
        if (found) return found;
    }
    return nil;
}

static NSMenuItem *DPGitLabMenuItem(NSString *space) {
    NSDictionary *instance = DPGitLabInstance(space);
    NSString *error = DPGitLabError(space);
    NSString *title = !instance ? @"GitLab — set up in DiaTweaks Settings" : error ? [@"GitLab — " stringByAppendingString:error] : @"GitLab";
    NSMenuItem *item = DPMenuItem(title, ^{
        NSMutableDictionary *changed = [instance mutableCopy];
        changed[@"enabled"] = @(![instance[@"enabled"] boolValue]);
        DPGitLabSaveInstance(space, changed);
        DPGitLabRefresh(YES);
    });
    item.tag = DPGitLabMenuTag;
    item.enabled = instance != nil;
    item.state = [instance[@"enabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    return item;
}

static void DPGitLabMenuOpened(NSNotification *note) {
    NSMenu *menu = DPGitLabFindPullRequestsMenu(note.object);
    if (!menu || !DPGitLabMergeRequests.on) return;
    for (NSInteger i = menu.numberOfItems - 1; i >= 0; i--) if ([menu itemAtIndex:i].tag == DPGitLabMenuTag) [menu removeItemAtIndex:i];
    NSInteger after = [menu indexOfItem:DPGitLabItemTitled(menu, @"Bitbucket")];
    [menu insertItem:DPGitLabMenuItem(DPGitLabMenuSpace ?: DPGitLabFrontSpace(NULL)) atIndex:after + 1];
}

static void DPGitLabRow_rightMouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    DPGitLabMenuSpace = DPGitLabEval(self, @"viewModel.delegate.delegate.spaceID.rawValue");
    DPCallOriginal(DPGitLabRow_rightMouseDown, self, event);
}

// Dia's Refresh, Created by Me and Review Requests reach GitLab too. The switches are read from Dia's own configuration on
// the next refresh, after Dia has saved the change.
static void DPGitLabCallback_perform(NSMenuItem *self, SEL _cmd, id sender) {
    BOOL ours = DPGitLabMergeRequests.on && DPGitLabIsPullRequestsMenu(self.menu)
        && [@[@"Refresh", @"Created by Me", @"Review Requests"] containsObject:self.title];
    DPCallOriginal(DPGitLabCallback_perform, self, sender);
    if (ours) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{ DPGitLabRefresh(YES); });
}

void DPGitLabInstallMenu(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidBeginTrackingNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { DPGitLabMenuOpened(note); }];
    // A menu opened another way (Control-click) falls back to the front window's Space, not the last row right-clicked.
    [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidEndTrackingNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { DPGitLabMenuSpace = nil; }];
    DPHook(DPDiaTabGroupCell, @selector(rightMouseDown:), (IMP)DPGitLabRow_rightMouseDown);
    DPHook(DPDiaCallbackMenuItem, @selector(performWithSender:), (IMP)DPGitLabCallback_perform);
}
