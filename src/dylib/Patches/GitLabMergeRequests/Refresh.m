#import "GitLabMergeRequests.h"

static const NSTimeInterval DPGitLabInterval = 300, DPGitLabMinimumGap = 120;
static NSMutableDictionary<NSString *, DPGitLabPlanState *> *DPGitLabStates;  // Per Space, for this launch.
static NSMutableDictionary<NSString *, NSString *> *DPGitLabErrors;           // Per Space: the last fetch's failure.
static NSDate *DPGitLabLastRefresh;
static NSMutableSet<NSString *> *DPGitLabActiveSpaces;  // Spaces whose folder this launch has filled: what turning it off clears.
static BOOL DPGitLabRefreshing, DPGitLabPending;

NSString *DPGitLabError(NSString *space) { return DPGitLabErrors[space]; }

static void DPGitLabRefreshFolder(DPGitLabFolder *folder, void (^done)(void)) {
    NSDictionary *instance = DPGitLabInstance(folder.space);
    if (!instance) return done();
    // The folder's own Created by Me and Review Requests, as Dia keeps them for it.
    NSArray<NSNumber *> *buckets = DPGitLabFolderBuckets(NSApp.delegate, folder.groupID) ?: @[@YES, @YES];
    void (^apply)(NSArray<DPGitLabMR *> *) = ^(NSArray<DPGitLabMR *> *mrs) {
        // Read again now, not when the fetch began: the switch, the instance or the folder's tabs may have changed since.
        NSDictionary *current = DPGitLabInstance(folder.space);
        BOOL enabled = DPGitLabMergeRequests.on && [current[@"enabled"] boolValue] && [current[@"id"] isEqual:instance[@"id"]]
            && [current[@"baseURL"] isEqual:instance[@"baseURL"]];
        NSArray<DPGitLabTab *> *tabs = DPGitLabTabsOf(folder, DPGitLabHost(instance));
        if (!tabs) return done();
        DPGitLabPlan *plan = DPGitLabMakePlan(tabs, mrs, enabled, DPGitLabStates[folder.space], NSDate.date);
        DPGitLabStates[folder.space] = plan.state;
        DPGitLabApply(folder, plan, done);
    };
    // Off, for the whole patch or this Space: close what this launch opened once, then leave the folder to the user.
    if (!DPGitLabMergeRequests.on || ![instance[@"enabled"] boolValue]) {
        if (![DPGitLabActiveSpaces containsObject:folder.space]) return done();
        [DPGitLabActiveSpaces removeObject:folder.space];
        return apply(@[]);
    }
    [DPGitLabActiveSpaces addObject:folder.space];
    DPGitLabFetchMRs(instance, DPGitLabToken(instance[@"id"]), buckets[0].boolValue, buckets[1].boolValue, ^(NSArray *mrs, NSString *error) {
        if (error && ![error isEqual:DPGitLabErrors[folder.space]]) DPGitLabLog(@"%@: %@", instance[@"baseURL"], error);
        DPGitLabErrors[folder.space] = error;
        apply(mrs);  // nil on failure: the plan leaves the folder alone.
    });
}

// force skips the gap the timer keeps, for Refresh in the menu and changes in Settings; one asked for during a refresh
// runs after it. NO if no folder is on screen.
static BOOL DPGitLabRefreshNow(BOOL force) {
    if (DPTesting) return YES;  // make test flips the switch dozens of times: never in the user's real folder.
    if (!DPGitLabMergeRequests.on && !DPGitLabActiveSpaces.count) return YES;  // Off with nothing to clear.
    if (DPGitLabRefreshing) {
        DPGitLabPending = DPGitLabPending || force;
        return YES;
    }
    if (!force && DPGitLabLastRefresh && -DPGitLabLastRefresh.timeIntervalSinceNow < DPGitLabMinimumGap) return YES;
    NSArray<DPGitLabFolder *> *folders = DPGitLabFolders();
    if (!folders.count) return NO;
    DPGitLabRefreshing = YES;
    DPGitLabLastRefresh = NSDate.date;
    __block NSUInteger left = folders.count;
    for (DPGitLabFolder *folder in folders)
        DPGitLabRefreshFolder(folder, ^{
            if (--left) return;
            DPGitLabRefreshing = NO;
            if (!DPGitLabPending) return;
            DPGitLabPending = NO;
            DPGitLabRefreshNow(YES);
        });
    return YES;
}

void DPGitLabRefresh(BOOL force) { DPGitLabRefreshNow(force); }

// Dia builds the sidebar a while after launch, so the first refresh waits for a folder to show.
static void DPGitLabRefreshAtLaunch(int tries) {
    if (DPGitLabRefreshNow(YES) || tries <= 0) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ DPGitLabRefreshAtLaunch(tries - 1); });
}

void DPGitLabInstallRefresh(void) {
    DPGitLabStates = [NSMutableDictionary new];
    DPGitLabErrors = [NSMutableDictionary new];
    DPGitLabActiveSpaces = [NSMutableSet new];
    DPOnLaunch(^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ DPGitLabRefreshAtLaunch(6); });
        [NSTimer scheduledTimerWithTimeInterval:DPGitLabInterval repeats:YES block:^(NSTimer *timer) { DPGitLabRefresh(NO); }];
    });
}
