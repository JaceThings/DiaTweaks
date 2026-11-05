// Group Tabs by Domain, Expand All Tab Groups, Collapse All Tab Groups, Ungroup This Domain and Ungroup All Domains are
// one-shot commands in the tab context menu and the Tabs menu, shown while the Group Tabs patch is on, and Group Tabs by
// Domain also has a keyboard shortcut. Expand and Collapse use Dia's own tab-group update, so they change every group, not
// only groups that command created. The hooks only remember live browsers and web contents; nothing changes until one is chosen.
#import "StdPatch/StdPatch.h"

void DPInstallGroupTabs(void);

// Tracking.m: what the hooks remembered.
id DPCommandBrowser(void);  // The front window's browser, or the only one.
NSWindow *DPBrowserWindow(id browser);
id DPGroupingDelegate(id browser);
NSArray *DPTrackedContents(id browser);
long long DPSessionOf(id contents);

// Messages.m
long long DPLongID(id value);
id DPMsg(id object, SEL sel);
BOOL DPMsgBool(id object, SEL sel);
NSString *DPText(id value);

// Plan.m: which groups to create and which tabs to add to existing ones.
NSString *DPDomainKey(NSString *urlString);
NSString *DPGroupTitle(NSString *domain);  // Title.m. Shown on a new group; the host stays the grouping key.
NSArray<NSDictionary *> *DPOps(NSArray<NSDictionary *> *tabs, NSArray *groups);

// Registrable.m: eTLD+1 for Merge Subdomains, from a host DPDomainKey returned. A short rule, not the Public Suffix List.
NSString *DPRegistrableDomain(NSString *host);

// Order.m: where tabs sit, so undo can put them back.
NSDictionary *DPTabPlaces(NSDictionary<NSNumber *, NSString *> *urls);
void DPRestorePlaces(id delegate, id browser, NSDictionary *places);

void DPGroupTabsOnce(void);                      // Grouping.m
void DPGroupSelectedTabsOnce(void);              // Grouping.m. Only the front window's selected tabs.
NSSet<NSNumber *> *DPSelectedSessions(id browser);  // Selection.m. Nil unless two or more selected tabs are found.
void DPSetAllGroupsCollapsed(BOOL collapsed);  // Fold.m
void DPUngroupDomain(void);                      // Ungroup.m
void DPUngroupAllDomains(void);                  // Ungroup.m
// Grouping.m, also used by Tidy Tabs. An op is {op: create, title, ids} or {op: add, group, ids}; a create without a
// title leaves the group for Dia's AI to name. Undo is Command-Z
// right after, and ungroups `ids` and puts them back at `places`.
void DPRunOps(id delegate, id browser, NSArray<NSDictionary *> *ops, NSUInteger index, void (^done)(void));
void DPOfferUndo(id delegate, id browser, NSArray *ids, NSDictionary *places);
void DPOfferRegroup(id delegate, id browser, NSArray<NSDictionary *> *ops);  // Undo runs `ops` again.
BOOL DPCanUndoGrouping(void);
void DPForgetGroupingUndo(void);
void DPInstallGroupMenus(void);  // Menu.m
void DPInstallGroupTabsShortcut(void);  // Shortcut.m
NSDictionary *DPDefaultGroupTabsShortcut(void);
