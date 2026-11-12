#import "StdPatch/StdPatch.h"

extern DPPatch DPCommandBarHideTab;

void DPExpectNewTab(NSWindow *window);  // From a new tab shortcut or click: what's new next is left out at once.
void DPStopExpecting(void);             // The new tab won't have the bar over it.
void DPHideTabRow(NSString *tabID, NSWindow *window);
void DPShowTabRow(NSString *tabID, BOOL closing);  // closing: it stays out until it's gone.
BOOL DPHidesTab(NSString *tabID);
BOOL DPHidingATab(void);  // Holding the lists still: a bar is open over a hidden tab, or one is on its way.
void DPParkTab(NSString *tabID, BOOL parked);
void DPHideBlank(NSString *tabID, BOOL hidden);  // Kept out the same way, so an empty window shows nothing open.
BOOL DPParksTab(NSString *tabID);
BOOL DPParkingAny(void);

void DPInstallFrozenLists(void);
void DPFreezeLists(NSWindow *window);
NSString *DPRowName(NSCollectionView *list, NSIndexPath *path);
NSString *DPTabIn(NSString *rowName);  // The tab a row shows, if it shows one.
NSArray<NSString *> *DPListedTabs(NSWindow *window);
void DPRelayoutLists(void);
NSRect DPDiaRowFrame(NSCollectionViewLayout *layout, NSIndexPath *path);
void DPInstallParkedRows(void);
BOOL DPIsLeftOutRow(NSCollectionView *list, NSIndexPath *path);
CGFloat DPClosedUp(NSCollectionViewLayout *layout, NSRect frame);
CGFloat DPParkedHeight(NSCollectionViewLayout *layout);
NSCollectionViewLayoutAttributes *DPClosedAttributes(NSCollectionViewLayout *layout, NSCollectionViewLayoutAttributes *attributes);
NSString *DPVerifyHiddenRows(void);

void DPInstallHiddenStripTab(void);
void DPHoldStrips(NSWindow *window);
NSString *DPStripTabID(NSView *tabView);

extern const uintptr_t DPFirstFill;  // A selection style below this has no fill: not selected.
NSView *DPIvarView(NSView *view, const char *name);
uintptr_t *DPSelectionStyle(NSView *background);
NSView *DPTabShapeView(NSView *background);
uint8_t *DPTabShape(NSView *background);
BOOL DPDrawnSelected(NSView *background);
BOOL DPInStrip(NSView *view);
void DPNoteLook(NSView *background);
NSArray *DPSelectedLook(NSView *button);

void DPInstallStandIn(void);
BOOL DPIsNewTabButton(NSView *view);
void DPInstallPress(void);
void DPStandInFor(NSWindow *window, NSString *tabID);  // The hidden tab the window's bar is over, or nil once it closes.
void DPStandInWhileSwitching(NSWindow *window, NSString *tabID, NSString *leaving);
BOOL DPSwitchingTo(NSView *background);
void DPEndSwitch(NSWindow *window);
void DPRefreshStandIns(void);
void DPInstallFrontTab(void);
void DPUnselectFrontTab(NSView *background, BOOL standingIn);
void DPGiveBackSelection(NSView *background);
BOOL DPHoldsSelection(NSView *background);
NSString *DPVerifyStandIn(NSWindow *window, NSString *tabID);
