#import "Library.h"
static char DPLibraryInteractiveHostKey;
@interface DPLibraryInteractiveHost : NSObject
@property(weak) DPLibraryController *owner;
@property BOOL nativeLayer, nativeClip;
@end
@implementation DPLibraryInteractiveHost @end
void DPLibraryUpdateInteractiveLayout(DPLibraryController *controller) {
    if (!controller.interacting || !controller.sidebarHost) return;
    NSView *host = controller.sidebarHost;
    DPLibraryInteractiveHost *state = DPGet(host,&DPLibraryInteractiveHostKey);
    if (!state) {
        state = [DPLibraryInteractiveHost new]; state.owner = controller; state.nativeLayer = host.wantsLayer;
        host.wantsLayer = YES; state.nativeClip = host.layer.masksToBounds; DPSet(host,&DPLibraryInteractiveHostKey,state);
        host.layer.masksToBounds = YES;
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    CGFloat seam = controller.expandedWidth*controller.expansion;
    // A layer-only translation leaves NSScrollView's visibleRect at the old
    // origin, so AppKit paints only the left portion then slides missing pixels.
    // Move the full-width view: viewport clipping and hit testing now agree.
    controller.view.layer.transform = CATransform3DIdentity;
    [controller.view setFrameOrigin:NSMakePoint(seam-controller.expandedWidth,0)];
    DPLibraryMoveCoveredTabs(controller,seam);
    [CATransaction commit];
}
void DPLibraryEndInteractiveLayout(DPLibraryController *controller) {
    if (!controller.interacting) return;
    controller.interacting = NO;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (controller.expanded) DPLibraryCoverTabs(controller);
    DPLibraryRestoreCoveredMotion(controller); controller.view.layer.transform = CATransform3DIdentity;
    [controller.view setFrameOrigin:NSZeroPoint];
    NSView *host = controller.sidebarHost;
    DPLibraryInteractiveHost *state = DPGet(host,&DPLibraryInteractiveHostKey);
    if (state.owner == controller) {
        host.layer.masksToBounds = state.nativeClip;
        if (!state.nativeLayer) host.wantsLayer = NO;
        DPSet(host,&DPLibraryInteractiveHostKey,nil);
    }
    [CATransaction commit];
}
