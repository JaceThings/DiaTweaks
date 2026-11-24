#import "Gesture.h"
DPLibraryController *DPLibraryForWindow(NSWindow *window);
@implementation DPLibraryGesture
- (void)resetForWindow:(NSWindow *)window {
    if (self.active) [self finishCancelled:NO];
    self.window = window; self.controller = nil; self.x = self.y = self.velocity = 0;
    self.last = self.moved = 0; self.active = self.consumed = self.nativePass = NO; self.pending = [NSMutableArray new]; self.generation++;
}
- (void)recordX:(CGFloat)x y:(CGFloat)y time:(NSTimeInterval)time {
    NSTimeInterval delta = time-self.last;
    if (fabs(x)>.01) { if (self.last && delta>0 && delta<.15) self.velocity = .5*self.velocity+.5*x/delta; self.moved = time; }
    self.x += x; self.y += y; self.last = time;
}
- (BOOL)begin {
    DPLibraryController *previous = DPLibraryForWindow(self.window);
    self.initiallyOpen = previous.expanded && !previous.closing;
    self.controller = DPLibraryBeginInteraction(self.window);
    if (!self.controller) return NO;
    self.start = self.controller.expansion; self.active = self.consumed = YES;
    [self apply]; return YES;
}
- (void)apply {
    DPLibraryController *controller = self.controller; if (!controller.expanded || !controller.interacting) return;
    CGFloat span = MAX(300,controller.expandedWidth);
    // Discard travel beyond either edge so reversing responds immediately.
    // Otherwise an overswipe builds invisible distance the finger must undo.
    self.x = MAX(-self.start*span,MIN((1-self.start)*span,self.x));
    controller.expansion = MAX(0,MIN(1,self.start+self.x/span));
    DPLibraryUpdateHosts(controller);
}
- (void)finishCancelled:(BOOL)cancelled {
    if (!self.active) return; self.active = NO; self.generation++;
    DPLibraryController *controller = self.controller; if (!controller.expanded || !controller.interacting) return;
    CGFloat velocity = self.last-self.moved > .08 ? 0 : self.velocity;
    BOOL opening = controller.expansion >= .5;
    if (velocity>1200 && controller.expansion>.35) opening = YES;
    if (velocity < -1200 && controller.expansion<.65) opening = NO;
    if (cancelled) opening = self.initiallyOpen;
    DPLibraryAnimate(controller,opening); self.controller = nil;
}
@end
