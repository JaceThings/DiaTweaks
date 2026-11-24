#import "Library.h"
#import "Patches/EdgeToEdge/EdgeToEdge.h"
static char DPLibraryHostKey;
@interface DPLibraryHostSlot : NSObject
@property(weak) DPLibraryController *owner;
@property NSRect nativeFrame, underlyingFrame;
@property NSSize superSize;
@property BOOL sidebar, moving;
@end
@implementation DPLibraryHostSlot @end
NSRect DPLibraryNativeFrame(NSView *view) {
    DPLibraryHostSlot *slot=DPGet(view,&DPLibraryHostKey);
    return slot ? slot.underlyingFrame : view.frame;
}
static void DPLibraryHostSetFrame(NSView *,SEL,NSRect);
static NSRect DPLibraryAdjustedHostFrame(DPLibraryHostSlot *slot,NSRect frame) {
    DPLibraryController *owner = slot.owner; if (!owner.expanded) return frame;
    if (slot.sidebar) {
        owner.originalWidth = NSWidth(frame);
        owner.expandedWidth = MAX(NSWidth(frame),MIN(510,NSWidth(owner.window.contentView.bounds)-320));
        frame.size.width = owner.originalWidth+(owner.expandedWidth-owner.originalWidth)*owner.expansion;
    } else if (owner.pageHost.superview && owner.sidebarHost) {
        NSRect side = [owner.pageHost.superview convertRect:owner.sidebarHost.bounds fromView:owner.sidebarHost];
        CGFloat delta = MAX(0,NSMaxX(side)-NSMinX(frame));
        // Keep Chromium's viewport at its native width. Library translates
        // the page off the window's right edge rather than reflowing websites.
        frame.origin.x += delta;
    }
    return frame;
}
static void DPLibraryPaintHost(NSView *view,DPLibraryHostSlot *slot) {
    NSRect adjusted = DPLibraryAdjustedHostFrame(slot,slot.underlyingFrame);
    if (NSEqualRects(view.frame,adjusted)) return;
    IMP setFrame = class_getMethodImplementation(NSView.class,@selector(setFrame:));
    ((void (*)(id,SEL,NSRect))setFrame)(view,@selector(setFrame:),adjusted);
}
static void DPLibraryPlaceHost(NSView *view,DPLibraryHostSlot *slot,NSRect native) {
    if (slot.sidebar && !slot.owner.ownsHost && slot.owner.expanded &&
        (NSWidth(native)<1 || NSHeight(native)<1 || NSMinX(native)<NSMinX(slot.nativeFrame)-1)) {
        DPLibraryDismissForWindow(slot.owner.window);
        IMP original = DPOriginalIMP(view,@selector(setFrame:),(IMP)DPLibraryHostSetFrame);
        ((void (*)(id,SEL,NSRect))original)(view,@selector(setFrame:),native); return;
    }
    NSRect painted = view.frame;
    if (slot.owner.expanded && slot.sidebar && fabs(NSWidth(native)-NSWidth(painted)) < .5) native.size.width = slot.nativeFrame.size.width;
    CGFloat translation=NSMinX(painted)-NSMinX(slot.underlyingFrame);
    if (slot.owner.expanded && !slot.sidebar && translation>.5 && fabs(NSMinX(native)-(NSMinX(slot.nativeFrame)+translation))<.5) {
        // Dia may request a new frame with Library's temporary sidebar width
        // subtracted. Restore that exact reservation before other patches see it.
        CGFloat parentDelta=NSWidth(view.superview.bounds)-slot.superSize.width;
        if(fabs(NSWidth(native)-(NSWidth(slot.nativeFrame)+parentDelta-translation))<.5) native.size.width+=translation;
        native.origin.x-=translation;
    } else if (slot.owner.expanded && !slot.sidebar && translation>.5 && fabs(NSMinX(native)-NSMinX(painted))<.5) {
        // AppKit can instead autoresize our already-painted frame. Convert it
        // back to the native frame, including another patch's padding/insets.
        native.origin.x += NSMinX(slot.nativeFrame)-NSMinX(painted);
        native.origin.y += NSMinY(slot.nativeFrame)-NSMinY(painted);
        native.size.width += NSWidth(slot.nativeFrame)-NSWidth(painted);
        native.size.height += NSHeight(slot.nativeFrame)-NSHeight(painted);
    }
    if (slot.sidebar && slot.owner.ownsHost) native.size.width = 0;
    slot.nativeFrame = native; slot.moving = YES;
    // Let Dia and Edge-to-Edge record their unmodified requested frame first.
    // Library's temporary frame must never become another patch's baseline.
    IMP original = DPOriginalIMP(view,@selector(setFrame:),(IMP)DPLibraryHostSetFrame);
    ((void (*)(id,SEL,NSRect))original)(view,@selector(setFrame:),native);
    slot.underlyingFrame = view.frame; DPLibraryPaintHost(view,slot);
    slot.superSize = view.superview.bounds.size; slot.moving = NO;
}
static void DPLibraryHostSetFrame(NSView *self,SEL _cmd,NSRect frame) {
    DPLibraryHostSlot *slot = DPGet(self,&DPLibraryHostKey);
    if (!slot || slot.moving) return DPCallOriginal(DPLibraryHostSetFrame,self,frame);
    DPLibraryPlaceHost(self,slot,frame);
}
static void DPLibraryHostSetSize(NSView *self,SEL _cmd,NSSize size) {
    DPLibraryHostSlot *slot = DPGet(self,&DPLibraryHostKey);
    if (!slot || slot.moving) return DPCallOriginal(DPLibraryHostSetSize,self,size);
    NSSize delta = NSMakeSize(NSWidth(self.superview.bounds)-slot.superSize.width,NSHeight(self.superview.bounds)-slot.superSize.height);
    if (fabs(size.width-(NSWidth(self.frame)+delta.width)) < .5) size.width = NSWidth(slot.nativeFrame)+delta.width;
    if (fabs(size.height-(NSHeight(self.frame)+delta.height)) < .5) size.height = NSHeight(slot.nativeFrame)+delta.height;
    NSRect frame = slot.nativeFrame; frame.size = size; DPLibraryPlaceHost(self,slot,frame);
}
static void DPLibraryHostSetOrigin(NSView *self,SEL _cmd,NSPoint origin) {
    DPLibraryHostSlot *slot = DPGet(self,&DPLibraryHostKey);
    if (!slot || slot.moving) return DPCallOriginal(DPLibraryHostSetOrigin,self,origin);
    if (fabs(origin.x-NSMinX(self.frame)) < .5) origin.x = NSMinX(slot.nativeFrame);
    if (fabs(origin.y-NSMinY(self.frame)) < .5) origin.y = NSMinY(slot.nativeFrame);
    NSRect frame = slot.nativeFrame; frame.origin = origin; DPLibraryPlaceHost(self,slot,frame);
}
static void DPLibraryHostHidden(NSView *self,SEL _cmd,BOOL hidden) {
    DPLibraryHostSlot *slot = DPGet(self,&DPLibraryHostKey);
    if (hidden && slot.sidebar && slot.owner.expanded) DPLibraryDismissForWindow(slot.owner.window);
    DPCallOriginal(DPLibraryHostHidden,self,hidden);
}
static void DPLibraryHostMoving(NSView *self,SEL _cmd,NSWindow *window) {
    DPLibraryHostSlot *slot = DPGet(self,&DPLibraryHostKey);
    if (slot.owner.expanded && window != slot.owner.window) DPLibraryDismissForWindow(slot.owner.window);
    DPCallOriginal(DPLibraryHostMoving,self,window);
}
void DPLibraryBindHost(NSView *view,DPLibraryController *owner,BOOL sidebar) {
    DPLibraryHostSlot *slot = [DPLibraryHostSlot new]; slot.owner = owner; slot.sidebar = sidebar;
    NSValue *requested = sidebar ? nil : DPRequestedFrame(view);
    slot.nativeFrame = requested ? requested.rectValue : view.frame;
    // The first placement starts from the already-adjusted page. A zero
    // baseline looks like a Library translation and applies its insets twice.
    slot.underlyingFrame = view.frame; slot.superSize = view.superview.bounds.size;
    DPSet(view,&DPLibraryHostKey,slot);
    DPHookClass(view.class,@selector(setHidden:),(IMP)DPLibraryHostHidden);
    DPHookClass(view.class,@selector(viewWillMoveToWindow:),(IMP)DPLibraryHostMoving);
    DPHookClass(view.class,@selector(setFrame:),(IMP)DPLibraryHostSetFrame);
    DPHookClass(view.class,@selector(setFrameSize:),(IMP)DPLibraryHostSetSize);
    DPHookClass(view.class,@selector(setFrameOrigin:),(IMP)DPLibraryHostSetOrigin);
    view.frame = slot.nativeFrame;
}
void DPLibraryRestoreHost(NSView *view,DPLibraryController *owner) {
    DPLibraryHostSlot *slot = DPGet(view,&DPLibraryHostKey); if (slot.owner != owner) return;
    DPSet(view,&DPLibraryHostKey,nil); view.frame = slot.nativeFrame; view.needsLayout = YES;
}
void DPLibraryUpdateHost(NSView *view,DPLibraryController *owner) {
    DPLibraryHostSlot *slot = DPGet(view,&DPLibraryHostKey); if (slot.owner != owner) return;
    slot.moving = YES; DPLibraryPaintHost(view,slot); slot.moving = NO;
}
