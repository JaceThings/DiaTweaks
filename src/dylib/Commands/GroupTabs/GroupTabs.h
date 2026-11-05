// Group Tabs by Domain is a one-shot command in the tab context menu and the Tabs menu, shown while its patch is on.
// Group Tabs by Domain in All Windows sits beside it and does the same once for every open window. The hooks only remember
// live browsers and web contents so the command can read each tab's session ID; nothing is grouped until it's chosen.
#import "StdPatch/StdPatch.h"

void DPInstallGroupTabs(void);

// Tracking.m: what the hooks remembered.
id DPCommandBrowser(void);  // The front window's browser, or the only one.
NSArray *DPCommandBrowsers(void);  // One browser per open window, front to back.
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
NSArray<NSDictionary *> *DPOps(NSArray<NSDictionary *> *tabs, NSArray *groups);

// Order.m: where tabs sit, so undo can put them back.
NSDictionary *DPTabPlaces(NSDictionary<NSNumber *, NSString *> *urls);
// Same as DPTabPlaces, but only the tabs in `window`. Nil when that window can't be told apart from the others.
NSDictionary *DPTabPlacesInWindow(NSWindow *window, NSDictionary<NSNumber *, NSString *> *urls);
void DPRestorePlaces(id delegate, id browser, NSDictionary *places, void (^done)(void));

void DPGroupTabsOnce(void);  // Grouping.m. The front window.
void DPGroupTabsAllWindows(void);  // Grouping.m. Every open window. One Command-Z afterwards undoes each of them.
// Grouping.m, also used by Tidy Tabs. An op is {op: create, title, ids} or {op: add, group, ids}; a create without a
// title leaves the group for Dia's AI to name. Undo is Command-Z
// right after, and ungroups `ids` and puts them back at `places`.
void DPRunOps(id delegate, id browser, NSArray<NSDictionary *> *ops, NSUInteger index, void (^done)(void));
void DPOfferUndo(id delegate, id browser, NSArray *ids, NSDictionary *places);
void DPInstallGroupMenus(void);  // Menu.m
