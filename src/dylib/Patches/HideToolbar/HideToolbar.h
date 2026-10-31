// Shared by hide toolbar and reveal on hover, which only works on top of it.
#import "StdPatch/StdPatch.h"

extern DPPatch DPHideToolbar, DPRevealToolbarOnHover;
extern NSHashTable<NSView *> *DPPanes;  // Every content pane laid out so far.
// Windows that never show their toolbar, whether or not Hide toolbar is on, such as Little Dia. Relayout panes after changing it.
extern NSHashTable<NSWindow *> *DPToolbarlessWindows;
BOOL DPToolbarless(NSView *view);

// Shows the hidden toolbar while the pointer is at the top of a pane. One per pane.
@interface DPToolbarHover : NSObject
@property (nonatomic, weak) NSView *pane, *bar, *bookmarks;
@property (nonatomic, strong) NSTrackingArea *tracking;
@property (nonatomic, strong) NSTimer *animation, *hideTimer;
@property (nonatomic) BOOL revealed;
@property (nonatomic) CGFloat progress;
+ (DPToolbarHover *)forPane:(NSView *)pane;  // nil until the pane is laid out.
+ (DPToolbarHover *)attachToPane:(NSView *)pane;
- (void)updateForBar:(NSView *)bar bookmarks:(NSView *)bookmarks;
@end

// Layout.m
NSRect DPLaidOutFrame(NSView *view);  // Where Dia put the view, before the patch moved it.
CGFloat DPTop(NSView *pane, NSRect r);  // Distances from the pane's top, whichever way it's flipped.
CGFloat DPBottom(NSView *pane, NSRect r);
NSView *DPBookmarksUnder(NSView *pane, NSView *bar);
void DPApplyToolbar(NSView *pane);
void DPRelayoutPanes(void);
