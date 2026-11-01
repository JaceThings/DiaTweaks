#import "Controller.h"

NSMutableSet<DPPeekController *> *DPPeekControllers;

@implementation DPPeekController
- (void)dismiss {
    if (self.closing || self.dismissing) return;
    self.dismissing = YES;
    __weak DPPeekController *weak = self;
    DPPeekAnimate(self.overlay, NO, ^{ [weak close]; });
}
- (void)close {
    if (self.closing) return;
    self.closing = YES;
    if (self.keyMonitor) [NSEvent removeMonitor:self.keyMonitor];
    self.keyMonitor = nil;
    [(NSObject *)self.contents stop];
    if (self.overlay.host) [self.contents detachFromPaneHostView:self.overlay.host];
    NSWindow *window = self.overlay.window;
    [self.overlay.layer removeAllAnimations];
    [self.overlay.card.layer removeAllAnimations];
    [self.overlay removeFromSuperview];
    self.overlay.dismiss = nil;
    self.overlay = nil;
    self.contents = nil;
    if (self.source.window == window) [window makeFirstResponder:self.source];
    [DPPeekControllers removeObject:self];
}
@end

void DPPeekCloseContents(id contents) {
    for (DPPeekController *preview in DPPeekControllers.allObjects)
        if (preview.sourceContents == contents) [preview close];
}

void DPPeekCloseWindow(NSWindow *window) {
    for (DPPeekController *preview in DPPeekControllers.allObjects)
        if (preview.overlay.window == window) [preview close];
}

void DPPeekCloseAll(void) {
    for (DPPeekController *preview in DPPeekControllers.allObjects) [preview close];
}

NSString *DPPeekVerify(DPPatch *patch) {
    for (DPPeekOverlay *overlay in DPFindViews("DPPeekOverlay")) {
        if (!patch->on) return @"Peek remains visible while disabled";
        if (overlay.host.window != overlay.window || ![overlay.host isDescendantOf:overlay.card]) return @"Peek is not embedded in its page";
        if (NSIsEmptyRect(overlay.host.frame)) return @"Peek content has no visible size";
    }
    return nil;
}
