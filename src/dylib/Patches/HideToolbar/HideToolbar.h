#import "StdPatch/StdPatch.h"
#include <simd/simd.h>

extern DPPatch DPHideToolbar, DPRevealToolbarOnHover, DPShowToolbarWithSidebar, DPShowToolbarOnNewTab, DPShowToolbarWithTopTabs, DPPlainSelectedTab, DPKeepBookmarksBar;
extern DPPatch DPShowLoadingProgress, DPNavigationInSidebar;
extern NSHashTable<NSView *> *DPPanes;

@interface DPToolbarHover : NSObject
@property (nonatomic, weak) NSView *pane, *bar, *bookmarks;
@property (nonatomic, strong) NSTrackingArea *tracking, *paneTracking;
@property (nonatomic, strong) NSTimer *animation, *hideTimer, *inPlaceAnimation;
@property (nonatomic, strong) NSHashTable<NSPopover *> *permissionPopovers;
@property (nonatomic) BOOL revealed, inPlace, touched, barsLowered;
@property (nonatomic) CGFloat progress, inPlaceProgress;
+ (DPToolbarHover *)forPane:(NSView *)pane;
+ (DPToolbarHover *)attachToPane:(NSView *)pane;
- (void)updateForBar:(NSView *)bar bookmarks:(NSView *)bookmarks;
- (BOOL)pointerAbovePage;
- (void)stopInPlace;
- (void)detach;
@end

NSRect DPLaidOutFrame(NSView *view);
CGFloat DPTop(NSView *pane, NSRect r);
CGFloat DPBottom(NSView *pane, NSRect r);
NSView *DPBookmarksUnder(NSView *pane, NSView *bar);
BOOL DPKeptInPlace(NSView *pane);
BOOL DPTabsAtTop(NSWindow *window);
NSString *DPVerifyKeptInPlace(DPPatch *patch);
void DPApplyToolbar(NSView *pane);
void DPApplyToolbarOpacity(DPToolbarHover *hover);
BOOL DPToolbarHasPermissionRequest(DPToolbarHover *hover);
void DPInstallToolbarPermissionReveal(void);
void DPRelayoutPanes(void);
void DPApplyRelayoutPanes(DPPatch *patch);
void DPRepaintTabs(NSWindow *window);
void DPPlaceNavigationButtons(NSWindow *window);

// Back, forward and reload on the sidebar's profile row, pressing Dia's own in the hidden toolbar, or one button with them in a menu when they don't fit.
@interface DPNavigationHolder : NSView
@property (nonatomic, copy) NSArray<NSView *> *(^dia)(void);
@property (nonatomic, readonly) BOOL wanted;
+ (DPNavigationHolder *)inHeader:(NSView *)header create:(BOOL)create;
- (void)show:(BOOL)shown;
@end

void DPShowCopyToast(NSView *pane, NSString *message);

void DPShowProgressLine(NSView *pane, CGFloat fraction);
void DPFinishProgressLine(NSView *pane);
void DPRemoveProgressLine(NSView *pane);
BOOL DPShowsProgressLine(NSView *pane);

CAMetalLayer *DPProgressShaderLayer(void);
void DPDrawProgressShader(CAMetalLayer *layer, CGFloat progress, CGFloat cycle, simd_float3 primary, simd_float3 secondary);
BOOL DPProgressColorSlots(NSUInteger slots[2]);

NSMenu *DPProgressColorChoices(void);
void DPProgressColors(NSView *pane, NSString *choice, simd_float3 *primary, simd_float3 *secondary);
void DPInstallProgressColors(void);
extern BOOL DPSamplesProgressColors;
