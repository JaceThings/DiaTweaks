#import "StdPatch/StdPatch.h"

extern DPPatch DPSwipeNewProfile;

// Pull.m: follows a swipe that starts on the last profile past its edge.
void DPStartPull(NSEvent *event, NSView *sidebar);
NSEvent *DPPullEvent(NSEvent *event, BOOL *handled);
void DPEndPull(BOOL open);
BOOL DPIsPullIndicator(NSView *view);

// Events.m: Dia's New Profile command, and the scroll event that cancels Dia's own swipe.
BOOL DPHasNewProfileItem(void);
void DPOpenNewProfile(NSWindow *window);
NSEvent *DPCancelDiaSwipe(void);

// Glow.m: the curved glow for the sidebar's right edge, width points wide, kept for reuse.
id DPEdgeGlow(CGFloat width, CGFloat height, CGFloat scale, NSAppearance *appearance);

// Badge.m: the + in a ring that fills with the pull.
@interface DPPullBadge : CALayer
@property (nonatomic) CGFloat fill;  // 0–1, how much of the ring is drawn.
@property (nonatomic) BOOL full;
- (void)colorFor:(NSAppearance *)appearance scale:(CGFloat)scale;
@end

// Covers the sidebar while a swipe pulls past the last profile: a glow from the right edge, and a +
// that slides out with the pull and fills. It never takes clicks.
@interface DPPullIndicator : NSView
@property (nonatomic, readonly) BOOL full;
// How far past the last profile, where 1 is enough to create one. Call it every frame: it eases toward this.
- (void)pullTo:(CGFloat)progress;
// Plays the exit, then removes itself.
- (void)finish:(BOOL)created;
@end
