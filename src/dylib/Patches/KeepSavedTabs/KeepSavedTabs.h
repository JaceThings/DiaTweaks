#import "StdPatch/StdPatch.h"

extern DPPatch DPKeepSavedTabs;

// Tabs.m: finding tabs and what they are.
NSView *DPSavedEnclosing(NSView *view, Class cls);
BOOL DPSavedIsSaved(NSView *tab);  // Above the line between pinned and open tabs.
BOOL DPSavedKeepsTab(NSView *tab);  // Saved, and not a live folder item, so its ✕ is ours.
BOOL DPSavedIsSelected(NSView *tab);
NSString *DPSavedTabID(NSView *tab);
NSArray<NSView *> *DPSavedTabsIn(NSView *root);  // Visible ones, top to bottom.
NSView *DPSavedTabWithID(NSView *root, NSString *tabID);
NSButton *DPSavedCloseButton(NSView *tab);
NSUInteger DPSavedPanes(NSWindow *window);  // Pages showing side by side.
extern BOOL DPSavedSelecting;  // While DPSavedSelect clicks.
void DPSavedSelect(NSView *tab);
void DPSavedClickHeader(NSView *folder);

// Close.m: closing a saved tab's page and keeping the tab.
BOOL DPSavedClose(NSView *tab);
void DPInstallSavedClose(void);

// Command.m: ⌘W.
void DPInstallSavedCommand(void);

// Pages.m: which tabs have a page open.
BOOL DPSavedHasPage(NSView *tab);
void DPInstallSavedPages(void);

// Style.m: the buttons on saved tabs.
void DPSavedUpdate(NSView *tab);
void DPInstallSavedStyle(void);
