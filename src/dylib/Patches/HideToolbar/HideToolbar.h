// Shared by hide toolbar and its options, reveal on hover and show with the sidebar, which only work on top of it.
#import "StdPatch/StdPatch.h"

extern DPPatch DPHideToolbar, DPRevealToolbarOnHover, DPShowToolbarWithSidebar;
extern NSHashTable<NSView *> *DPPanes;  // Every content pane laid out so far.

// Shows the hidden toolbar while the pointer is at the top of a pane, or while the sidebar is open beside it. One per pane.
@interface DPToolbarHover : NSObject
@property (nonatomic, weak) NSView *pane, *bar, *bookmarks;
@property (nonatomic, strong) NSTrackingArea *tracking;
@property (nonatomic, strong) NSTimer *animation, *hideTimer, *sidebarAnimation;
@property (nonatomic) BOOL revealed, forSidebar;
@property (nonatomic) CGFloat progress, sidebarProgress;  // How far the pointer, and the sidebar, have brought the toolbar back.
+ (DPToolbarHover *)forPane:(NSView *)pane;  // nil until the pane is laid out.
+ (DPToolbarHover *)attachToPane:(NSView *)pane;
- (void)updateForBar:(NSView *)bar bookmarks:(NSView *)bookmarks;
@end

// Layout.m
NSRect DPLaidOutFrame(NSView *view);  // Where Dia put the view, before the patch moved it.
CGFloat DPTop(NSView *pane, NSRect r);  // Distances from the pane's top, whichever way it's flipped.
CGFloat DPBottom(NSView *pane, NSRect r);
NSView *DPBookmarksUnder(NSView *pane, NSView *bar);
BOOL DPSidebarDocked(NSView *pane);
void DPApplyToolbar(NSView *pane);
void DPApplyToolbarOpacity(DPToolbarHover *hover);
void DPRelayoutPanes(void);
