// GitLab merge requests: each Space's open merge requests on its GitLab instance, as tabs in Dia's own Pull Requests
// folder, next to GitHub's and Bitbucket's.
#import "StdPatch/StdPatch.h"
#import "Plan.h"

extern DPPatch DPGitLabMergeRequests;

// Config.m: a Space's instance is @{id, baseURL, name, enabled}; its token is in the keychain under its id.
NSDictionary *DPGitLabInstance(NSString *space);
void DPGitLabSaveInstance(NSString *space, NSDictionary *instance);
NSString *DPGitLabToken(NSString *instanceID);
BOOL DPGitLabSetToken(NSString *instanceID, NSString *token);  // nil or empty deletes it.
NSString *DPGitLabHost(NSDictionary *instance);

// Client.m. error is nil on success, otherwise a few words for the menu and Settings.
void DPGitLabFetchUser(NSString *baseURL, NSString *token, void (^done)(NSString *username, NSString *error));
void DPGitLabFetchMRs(NSDictionary *instance, NSString *token, BOOL created, BOOL review,
                      void (^done)(NSArray<DPGitLabMR *> *mrs, NSString *error));

// Mirror.swift: Dia's Swift objects by field name: "@appleScriptWindows.[0].@activeProfile.spaceID". nil if a step is missing.
NSString *DPGitLabEval(id root, NSString *path);
id DPGitLabEvalObject(id root, NSString *path);

// TabStore.swift: Dia's Live Folders and tab store, read only.
NSArray<NSString *> *DPGitLabPullRequestFolderIDs(id appDelegate);
NSArray<NSNumber *> *DPGitLabFolderBuckets(id appDelegate, NSString *groupID);          // [created by me, review requests]
NSArray<NSArray<NSString *> *> *DPGitLabGroupMembers(id appDelegate, NSString *groupID);  // [tab id, URL], nil if no such group.
BOOL DPGitLabHasGroup(id appDelegate, NSString *groupID);
NSString *DPGitLabGroupSpace(id appDelegate, NSString *groupID);  // The Space whose pinned area holds it.

// CreateTab.swift: through Dia's own tab store when its closures are the ones expected; NO or nil without calling Dia otherwise.
NSString *DPGitLabCreateTabInGroup(id appDelegate, NSString *groupID, NSString *url, NSString *title);  // The new tab's id.
BOOL DPGitLabRemoveTabs(id appDelegate, NSString *groupID, NSArray<NSString *> *tabIDs);

// Folder.m: a Space's Pull Requests folder, as Dia shows it in a window.
@interface DPGitLabFolder : NSObject
@property (nonatomic, copy) NSString *groupID, *space;
@property (nonatomic, strong) id browser, scriptWindow;  // Its window's ChromiumBrowser and DiaAppleScriptWindow.
@end
NSArray<DPGitLabFolder *> *DPGitLabFolders(void);  // One per Space whose window shows its folder.
// The folder's tabs and loose tabs in its window on this instance's merge requests; nil if Dia's tab store can't be read.
NSArray<DPGitLabTab *> *DPGitLabTabsOf(DPGitLabFolder *folder, NSString *host);
NSString *DPGitLabFrontSpace(NSString **name);  // The front window's Space, which Dia's UI calls its profile.
NSString *DPGitLabActiveTab(DPGitLabFolder *folder);
id DPGitLabScriptTab(DPGitLabFolder *folder, NSString *tabID);  // A loaded tab's DiaAppleScriptTab.
NSDictionary<NSString *, NSNumber *> *DPGitLabSessionsByURL(id browser);

void DPGitLabApply(DPGitLabFolder *folder, DPGitLabPlan *plan, void (^done)(void));  // Apply.m

// Refresh.m: at launch, on a timer and on Dia's Refresh; Settings and the switch force one.
void DPGitLabInstallRefresh(void);
void DPGitLabRefresh(BOOL force);
NSString *DPGitLabError(NSString *space);  // The last fetch's failure for that Space, or nil.

NSArray<NSView *> *DPGitLabRows(void);  // Rows.m
void DPGitLabInstallMenu(void);         // Menu.m
void DPGitLabLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);  // A failure worth a line in Console.
