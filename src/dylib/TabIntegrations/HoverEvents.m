#import "HoverInternal.h"

@implementation DPTabIntegrationHoverTracker (Events)
- (void)mouseEntered:(NSEvent *)event {
    [self.reveal invalidate];
    [self.dismiss invalidate];
    if (!DPAnyIntegrationEnabled() || !DPTabIntegrationTabForView(self.anchor)) return;
    if (self.host.window.visible) return;
    __weak DPTabIntegrationHoverTracker *weak = self;
    self.reveal = [NSTimer timerWithTimeInterval:0.35 repeats:NO block:^(NSTimer *_) { [weak show]; }];
    [NSRunLoop.mainRunLoop addTimer:self.reveal forMode:NSRunLoopCommonModes];
}

- (void)mouseExited:(NSEvent *)event {
    [self.reveal invalidate];
    [self.dismiss invalidate];
    if (!self.host.window.visible) return;
    __weak DPTabIntegrationHoverTracker *weak = self;
    self.dismiss = [NSTimer timerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *_) {
        DPTabIntegrationHoverTracker *tracker = weak;
        if (!tracker) return;
        [tracker reconcile];
        if (!tracker.host) { [tracker.dismiss invalidate]; return; }
        if ([tracker pointerInside:tracker.anchor] || [tracker.host containsPointer]) return;
        [tracker close];
        [tracker.dismiss invalidate];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.dismiss forMode:NSRunLoopCommonModes];
}
@end
