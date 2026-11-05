#import "GitLabMergeRequests.h"

static void DPGitLabInstall(void) {
    DPGitLabInstallRefresh();
    DPGitLabInstallMenu();
}

static void DPGitLabApplySwitch(DPPatch *patch) { DPGitLabRefresh(YES); }

// What a refresh relies on still reads as this patch expects: Dia's browser contexts and Live Folders, and for each Pull
// Requests folder its group and Space in the tab store and its own switches. Refreshes don't run under make test
// (DPTesting), which mustn't touch the user's real folder.
static NSString *DPGitLabVerify(DPPatch *patch) {
    if (!patch->on) return nil;
    if (!DPGitLabEvalObject(NSApp.delegate, @"controller.userDataController.browserContextDataControllers")) return @"can't read Dia's browser contexts";
    for (NSString *group in DPGitLabPullRequestFolderIDs(NSApp.delegate)) {
        if (!DPGitLabHasGroup(NSApp.delegate, group)) return @"can't find the Pull Requests folder in Dia's tab store";
        if (!DPGitLabFolderBuckets(NSApp.delegate, group)) return @"can't read the Pull Requests folder's switches";
        if (!DPGitLabGroupSpace(NSApp.delegate, group)) return @"can't read the Pull Requests folder's profile";
    }
    return nil;
}

DP_PATCH(DPGitLabMergeRequests) {
    .key = @"gitlabMergeRequests",
    .order = 88,
    .title = @"GitLab merge requests",
    .detail = @"Show your open GitLab merge requests in Dia's Pull Requests folder, next to GitHub and Bitbucket.",
    .hint = @"Each profile has its own instance and token, like its own GitHub sign-in. Options edit the profile of the front window.",
    .symbol = @"arrow.triangle.merge arrow.triangle.branch",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .install = DPGitLabInstall,
    .rows = DPGitLabRows,
    .apply = DPGitLabApplySwitch,
    .verify = DPGitLabVerify,
    .classes = DPClasses(DPDiaTabGroupCell, DPDiaBrowserDelegate, DPDiaScriptWindow, DPDiaScriptTab, DPDiaCallbackMenuItem),
};
