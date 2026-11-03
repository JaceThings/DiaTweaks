// Without chat usage, the command bar's bottom row only holds Go and two buttons that can't be used.
#import "StdPatch/StdPatch.h"

extern DPPatch DPCompactCommandBar, DPCompactWithChat;
void DPApplyCompactCommandBar(DPPatch *patch);

NSView *DPCommandBarPart(NSView *commandBar, const char *className);
BOOL DPChatLocked(NSView *view);
NSView *DPCompactToolbar(NSView *commandBar);  // The bottom row while the patch applies to this command bar, else nil.
void DPRememberChatLocked(BOOL locked);
NSView *DPGoButton(NSView *toolbar);

// Layout.m
NSSize DPCompactSize(NSView *container, NSSize size);  // Drops the bottom row's height from a container sized to the command bar.
void DPInstallCommandBarLayout(void);
void DPResizePopovers(void);

// NewTab.m
void DPInstallNewTabLayout(void);
void DPResizeNewTabPanels(void);
