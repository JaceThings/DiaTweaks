#import "Library.h"
static char DPLibraryBackdropKey;
@interface DPLibraryBackdropState : NSObject
@property(weak) DPLibraryController *owner;
@property NSRect nativeFrame;
@end
@implementation DPLibraryBackdropState @end
static NSRect DPLibraryBackdropFrame(NSView *view,DPLibraryBackdropState *state,NSRect frame) {
    DPLibraryController *owner = state.owner;
    if (owner.expanded && owner.sidebarHost) {
        NSRect side = [view.superview convertRect:owner.sidebarHost.bounds fromView:owner.sidebarHost];
        frame.size.width = MAX(NSWidth(frame),NSMaxX(side)-NSMinX(frame));
    }
    return frame;
}
static void DPLibraryBackdropSetFrame(NSView *self,SEL _cmd,NSRect frame) {
    DPLibraryBackdropState *state = DPGet(self,&DPLibraryBackdropKey);
    if (state) { state.nativeFrame = frame; frame = DPLibraryBackdropFrame(self,state,frame); }
    DPCallOriginal(DPLibraryBackdropSetFrame,self,frame);
}
void DPLibraryUpdateBackdrop(DPLibraryController *owner) {
    NSView *base = owner.backdrop;
    if (base && !base.superview) { owner.backdrop = nil; base = nil; }
    if (!base && owner.expanded) {
        base = DPFindView(owner.window.contentView.superview,^BOOL(NSView *view) {
            return [NSStringFromClass(view.class) containsString:@"WindowBackgroundBaseView"] &&
                !view.hiddenOrHasHiddenAncestor && NSMinX(view.frame) == 0 &&
                NSHeight(view.frame) > NSHeight(owner.window.contentView.bounds)*.8 &&
                NSWidth(view.frame) < NSWidth(owner.window.contentView.bounds)/2;
        });
        if (base) {
            DPLibraryBackdropState *state = [DPLibraryBackdropState new]; state.owner = owner; state.nativeFrame = base.frame;
            DPSet(base,&DPLibraryBackdropKey,state); owner.backdrop = base;
            DPHookClass(base.class,@selector(setFrame:),(IMP)DPLibraryBackdropSetFrame);
        }
    }
    DPLibraryBackdropState *state = DPGet(base,&DPLibraryBackdropKey); if (!state) return;
    if (!owner.expanded) {
        DPSet(base,&DPLibraryBackdropKey,nil); base.frame = state.nativeFrame; owner.backdrop = nil;
    } else if (!NSEqualRects(base.frame,DPLibraryBackdropFrame(base,state,state.nativeFrame))) base.frame = state.nativeFrame;
    // Native material pieces have fixed child frames on some Dia builds.
    for (NSView *child in base.subviews) if ([child isKindOfClass:NSVisualEffectView.class] && !NSEqualRects(child.frame,base.bounds)) child.frame = base.bounds;
}
