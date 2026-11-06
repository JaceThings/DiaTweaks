#import "StdPatch/StdPatch.h"

// Keeps each borrowed native button's original owner and layout for restoration.
@interface DPNavigationSlot : NSObject
@property(weak) NSView *view, *home, *owner;
@property NSRect originalFrame, forcedFrame;
@property NSUInteger index;
@property NSStackViewGravity gravity;
@property BOOL moving, originalHidden, forcedHidden, originalTranslates;
@property CGFloat originalAlpha;
@property NSAutoresizingMaskOptions originalMask;
@property NSArray<NSLayoutConstraint *> *constraints;
@end
DPNavigationSlot *DPNavigationSlotFor(NSView *view);
DPNavigationSlot *DPNavigationAttach(NSView *view, NSView *owner, NSView *destination, NSRect frame);
void DPNavigationRestore(DPNavigationSlot *slot);
void DPNavigationLayout(DPNavigationSlot *slot, NSRect frame);
void DPNavigationInstallControlHooks(NSView *view);
NSView *DPNavigationSourceToolbar(NSWindow *window);

extern DPPatch DPSidebarNavigationControls, DPSidebarNavigation, DPSidebarHideProfile;
@interface DPSidebarNavigationState : NSObject
@property(weak) NSView *toolbar, *hiddenProfile;
@property BOOL profileWasHidden;
@property NSHashTable<NSView *> *shiftedViews;
@property NSMutableDictionary<NSString *, DPNavigationSlot *> *toolbarControls;
@end
DPSidebarNavigationState *DPNavigationState(NSView *header, BOOL create);
void DPRestoreSidebarNavigation(DPSidebarNavigationState *state);
void DPPlaceSidebarNavigation(DPSidebarNavigationState *state, NSView *header);
void DPRefreshSidebarNavigation(NSView *header);
void DPApplySidebarNavigation(DPPatch *patch);
void DPInstallSidebarNavigationLayout(void);
void DPInstallSidebarNavigationLifecycle(void);

void DPRefreshHorizontalNavigation(NSView *strip);
void DPRestoreHorizontalNavigation(DPSidebarNavigationState *state);
BOOL DPHorizontalNavigationAvailable(NSView *strip);
