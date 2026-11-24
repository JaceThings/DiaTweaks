#import "Library.h"
#import "MotionClock.h"
static void DPRestoreLibraryResponder(DPLibraryController *owner) {
    NSResponder *responder=owner.previousResponder; owner.previousResponder=nil;
    // Opening a board can replace the page view while Library is closing.
    // Never give AppKit a detached view (or one now owned by another window).
    if([responder isKindOfClass:NSView.class]) {
        NSView *view=(NSView *)responder;
        if(view.window!=owner.window || view.hiddenOrHasHiddenAncestor) return;
    } else {
        NSResponder *next=responder; NSUInteger depth=0;
        while(next && next!=owner.window && depth++<64) next=next.nextResponder;
        if(next!=owner.window) return;
    }
    if(responder) [owner.window makeFirstResponder:responder];
}
@interface DPLibraryMotion : NSObject <DPLibraryAnimation>
@property(weak) DPLibraryController *owner;
@property BOOL opening;
@property CGFloat start;
@property CFTimeInterval began;
@property NSTimeInterval duration;
@property DPLibraryMotionClock *clock;
@end
@implementation DPLibraryMotion
- (void)stopAnimation { [self.clock stop]; self.clock = nil; }
- (void)tick:(CADisplayLink *)link {
    DPLibraryController *owner = self.owner;
    if (!owner.expanded) { [self stopAnimation]; return; }
    CFTimeInterval began = CACurrentMediaTime();
    CGFloat progress = MIN(1,MAX(0,(began-self.began)/self.duration));
    CGFloat eased = progress*progress*(3-2*progress);
    owner.expansion = self.start+((self.opening ? 1 : 0)-self.start)*eased;
    owner.view.alphaValue = 1; DPLibraryUpdateHosts(owner);
    if (progress >= 1) {
        [self stopAnimation]; owner.motion = nil;
        if (self.opening && owner.interacting) { DPLibraryEndInteractiveLayout(owner); [owner layout]; [owner.window makeFirstResponder:owner.preferredSectionResponder ?: owner.search]; }
        if (!self.opening) {
            DPLibraryUnmount(owner); owner.closing = NO;
            DPRestoreLibraryResponder(owner);
        }
    }
#ifdef DPLIBRARY_DIAGNOSTICS
    extern void DPLibraryRecordMotion(id,CFTimeInterval,BOOL,BOOL);
    DPLibraryRecordMotion(self,began,self.opening,progress>=1);
#endif
}
- (void)startAnimation {
    self.began = CACurrentMediaTime();
    self.clock = [DPLibraryMotionClock new];
    __weak DPLibraryMotion *weak = self;
    self.clock.frame = ^{ [weak tick:nil]; };
    [self.clock startForWindow:self.owner.window];
}
@end
void DPLibraryAnimate(DPLibraryController *controller,BOOL opening) {
    [controller.motion stopAnimation]; controller.motion = nil;
    controller.closing = !opening;
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion || !controller.window.visible || !DPSidebarLibrary.on || fabs((opening ? 1 : 0)-controller.expansion)<.001) {
        controller.expansion = opening ? 1 : 0; controller.view.alphaValue = 1;
        if (opening) { DPLibraryEndInteractiveLayout(controller); DPLibraryUpdateHosts(controller); [controller.window makeFirstResponder:controller.preferredSectionResponder ?: controller.search]; }
        else {
            DPLibraryUnmount(controller); controller.closing = NO;
            DPRestoreLibraryResponder(controller);
        }
        return;
    }
    DPLibraryMotion *motion = [DPLibraryMotion new]; motion.owner = controller; motion.opening = opening; motion.start = controller.expansion;
    motion.duration = MAX(.16,(opening ? .38 : .34)*fabs((opening ? 1 : 0)-motion.start)); controller.motion = motion;
    controller.interacting = YES; DPLibraryUpdateHosts(controller);
    [motion startAnimation];
}
