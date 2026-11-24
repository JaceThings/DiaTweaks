#import "Library.h"
static char DPLibraryCoveredKey;
@interface DPLibraryCovered : NSObject
@property(weak) DPLibraryController *owner;
@property BOOL nativeHidden;
@property NSRect nativeFrame;
@property NSImageView *snapshot;
@end
@implementation DPLibraryCovered @end
static void DPLibraryCoveredHidden(NSView *self,SEL _cmd,BOOL hidden) {
    DPLibraryCovered *state = DPGet(self,&DPLibraryCoveredKey);
    if (state.owner.expanded) { state.nativeHidden = hidden; hidden = YES; }
    DPCallOriginal(DPLibraryCoveredHidden,self,hidden);
}
static void DPLibraryPaintCovered(NSView *view,DPLibraryCovered *state) {
    IMP original = DPOriginalIMP(view,@selector(setHidden:),(IMP)DPLibraryCoveredHidden);
    ((void (*)(id,SEL,BOOL))original)(view,@selector(setHidden:),YES);
}
void DPLibraryCoverTabs(DPLibraryController *controller) {
    if (!controller.expanded) return;
    if (!controller.coveredViews) controller.coveredViews = [NSMutableArray new];
    for (NSView *view in controller.sidebarHost.subviews.copy) {
        NSString *name = NSStringFromClass(view.class);
        if ([view.identifier isEqual:@"DiaTweaks.SidebarLibrary.NativeSnapshot"]) continue;
        if (view == controller.view || DPIsKind(view,DPDiaSidebarHeader) || [name containsString:@"Grain"]) continue;
        DPLibraryCovered *state = DPGet(view,&DPLibraryCoveredKey);
        if (!state) {
            state = [DPLibraryCovered new]; state.owner = controller; state.nativeHidden = view.hidden;
            state.nativeFrame = view.frame;
            // Dia owns the real backing layers and may reset them during layout.
            // Move a frozen surface instead; leave native layout geometry alone.
            if (!view.hidden && NSWidth(view.bounds)>0 && NSHeight(view.bounds)>0) {
                NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
                if (rep) {
                    [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
                    NSImage *image = [[NSImage alloc] initWithSize:view.bounds.size]; [image addRepresentation:rep];
                    state.snapshot = [[NSImageView alloc] initWithFrame:state.nativeFrame];
                    state.snapshot.identifier = @"DiaTweaks.SidebarLibrary.NativeSnapshot";
                    state.snapshot.image = image; state.snapshot.imageScaling = NSImageScaleAxesIndependently;
                    state.snapshot.hidden = YES;
                    [controller.sidebarHost addSubview:state.snapshot positioned:NSWindowAbove relativeTo:view];
                }
            }
            DPHookClass(view.class,@selector(setHidden:),(IMP)DPLibraryCoveredHidden);
            DPSet(view,&DPLibraryCoveredKey,state); [controller.coveredViews addObject:view];
        }
        DPLibraryPaintCovered(view,state);
    }
}
void DPLibraryMoveCoveredTabs(DPLibraryController *controller,CGFloat offset) {
    for (NSView *view in controller.coveredViews) {
        DPLibraryCovered *state = DPGet(view,&DPLibraryCoveredKey);
        if (state.owner != controller || state.nativeHidden) continue;
        NSRect frame = state.nativeFrame; frame.origin.x += offset;
        CGFloat progress=MAX(0,MIN(1,controller.expansion)); frame.origin.y+=8*progress;
        state.snapshot.frame = frame; state.snapshot.alphaValue=1-progress; state.snapshot.hidden = NO;
    }
}
void DPLibraryRestoreCoveredMotion(DPLibraryController *controller) {
    for (NSView *view in controller.coveredViews) {
        DPLibraryCovered *state = DPGet(view,&DPLibraryCoveredKey);
        if (state.owner != controller) continue;
        state.snapshot.hidden = YES;
    }
}
void DPLibraryUncoverTabs(DPLibraryController *controller) {
    DPLibraryRestoreCoveredMotion(controller);
    for (NSView *view in controller.coveredViews) {
        DPLibraryCovered *state = DPGet(view,&DPLibraryCoveredKey);
        if (state.owner != controller) continue;
        [state.snapshot removeFromSuperview];
        DPSet(view,&DPLibraryCoveredKey,nil); view.hidden = state.nativeHidden;
    }
    controller.coveredViews = nil;
}
