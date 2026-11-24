#import "Patches/SidebarLibrary/Library.h"
#import <objc/runtime.h>
static char nativeKey;
static BOOL edge = YES, seamPadding;
static DPLibraryController *current;
static BOOL uncovered;
void DPLibraryEndInteractiveLayout(DPLibraryController *controller) {
    NSCAssert(uncovered,@"native sidebar is uncovered before temporary layer ownership is restored");
    uncovered=NO;
    NSCAssert(controller.view.hidden && !controller.view.superview,@"outgoing Library is hidden and detached before any origin/layer restoration can repaint it over native tabs");
    [controller.view setFrameOrigin:NSZeroPoint];
}
void DPLibraryDismissForWindow(NSWindow *window) { DPLibraryUnmount(current); }
@implementation DPLibraryController
- (void)layout {}
@end
id DPGet(id object,const void *key) { return objc_getAssociatedObject(object,key); }
void DPSet(id object,const void *key,id value) { objc_setAssociatedObject(object,key,value,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
BOOL DPIsKind(id view,const char *name) { return [[view identifier] isEqual:@(name)]; }
NSView *DPFindView(NSView *root,BOOL (^test)(NSView *)) { if(test(root))return root;for(NSView *child in root.subviews){NSView *match=DPFindView(child,test);if(match)return match;}return nil; }
void DPLibraryUncoverTabs(DPLibraryController *controller) { uncovered=YES; }
NSValue *DPRequestedFrame(NSView *view) { return DPGet(view,&nativeKey); }
@interface LibraryFrameRoot : NSView @end
@implementation LibraryFrameRoot
- (BOOL)isFlipped { return YES; }
@end
@interface LibraryWindowBackgroundBaseView : NSView @end
@implementation LibraryWindowBackgroundBaseView @end
@interface LibraryNativePage : NSView @end
@implementation LibraryNativePage @end
static void edgeFrame(NSView *view,SEL _cmd,NSRect frame) {
    DPSet(view,&nativeKey,@(frame));
    if(edge && !seamPadding) frame=NSInsetRect(frame,-6,-6);
    else if(edge) {
        // As in Dia, the vertical sidebar seam is not a window-edge inset.
        if(fabs(NSMinX(frame)-6)<.5) { frame.origin.x-=6; frame.size.width+=6; }
        CGFloat right=NSWidth(view.superview.bounds)-NSMaxX(frame), bottom=NSHeight(view.superview.bounds)-NSMaxY(frame);
        if(fabs(NSMinY(frame)-6)<.5) { frame.origin.y-=6; frame.size.height+=6; }
        if(fabs(bottom-6)<.5) frame.size.height+=6;
        if(fabs(right-6)<.5) frame.size.width+=6;
    }
    DPCallOriginal(edgeFrame,view,frame);
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1000,700) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    window.contentView=[[LibraryFrameRoot alloc] initWithFrame:NSMakeRect(0,0,1000,700)];
    NSView *background=[[LibraryWindowBackgroundBaseView alloc] initWithFrame:NSMakeRect(0,0,217,700)];
    NSVisualEffectView *material=[[NSVisualEffectView alloc] initWithFrame:background.bounds]; [background addSubview:material]; [window.contentView addSubview:background];
    NSView *page=[LibraryNativePage new];page.identifier=@DPDiaContentContainer;[window.contentView addSubview:page];
    page.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    DPHookClass(page.class,@selector(setFrame:),(IMP)edgeFrame);
    NSRect native=NSMakeRect(6,6,988,688);page.frame=native;
    DPLibraryController *controller=[DPLibraryController new];current=controller;controller.window=window;controller.view=[NSView new];
    for(NSUInteger pass=0;pass<20;pass++) {
        NSCAssert(DPLibraryMount(controller),@"Library mounts in native window");controller.expansion=1;DPLibraryUpdateHosts(controller);
        NSCAssert(!controller.view.hidden,@"reopening makes the previously detached surface visible again");
        NSCAssert(NSWidth(background.frame)==510 && NSWidth(material.frame)==510,@"native material fills the entire expanded Library without a band");
        for(NSUInteger layout=0;layout<10;layout++)page.frame=DPRequestedFrame(page).rectValue;
        NSCAssert(NSEqualRects(DPRequestedFrame(page).rectValue,native),@"temporary Library geometry cannot overwrite native requested frame");
        NSCAssert(NSWidth(page.frame)==NSWidth(NSInsetRect(native,-6,-6)) && NSMaxX(page.frame)>NSWidth(window.contentView.bounds),@"Library slides the full viewport beyond the right edge without website reflow");
        for(NSNumber *progress in @[@0,@.2,@.7,@.4,@1]) {
            controller.expansion=progress.doubleValue; DPLibraryUpdateHosts(controller);
            NSCAssert(NSWidth(page.frame)==1000 && NSMaxX(page.frame)>=1000,@"partial and reversed reveals never resize the page or expose a right-side gap");
        }
        NSRect reservation=DPRequestedFrame(page).rectValue; reservation.origin.x+=510; reservation.size.width-=510; page.frame=reservation;
        NSCAssert(NSWidth(page.frame)==1000 && NSEqualRects(DPRequestedFrame(page).rectValue,native),@"native sidebar-reservation feedback cannot shrink the frozen viewport");
        [page setFrameSize:native.size];
        DPLibraryUnmount(controller);
        NSCAssert(NSWidth(background.frame)==217 && NSWidth(material.frame)==217,@"closing restores the native material geometry");
        NSCAssert(NSEqualRects(page.frame,NSInsetRect(native,-6,-6)),@"closing restores the full page, without cumulative gaps");
    }
    NSCAssert(DPLibraryMount(controller),@"mount before resizing");controller.expansion=1;DPLibraryUpdateHosts(controller);
    [window setContentSize:NSMakeSize(800,600)];native=NSMakeRect(6,6,788,588);DPLibraryUpdateHosts(controller);
    NSCAssert(NSEqualRects(DPRequestedFrame(page).rectValue,native),@"autoresizing cannot feed painted Library width back into native geometry");
    page.frame=native;DPLibraryUpdateHosts(controller);
    NSCAssert(NSWidth(page.frame)==800 && NSMaxX(page.frame)>800,@"real window resizing changes the viewport once while Library still translates it");
    edge=NO;page.frame=native;DPLibraryUpdateHosts(controller);DPLibraryUnmount(controller);
    NSCAssert(NSEqualRects(page.frame,native),@"Edge-to-Edge off restores native padding after close");
    [window setContentSize:NSMakeSize(1000,700)]; edge=YES;
    NSView *sidebar=[[LibraryFrameRoot alloc] initWithFrame:NSMakeRect(0,0,228,700)];sidebar.autoresizingMask=NSViewHeightSizable;
    NSView *header=[[NSView alloc] initWithFrame:NSMakeRect(0,0,228,30)];header.identifier=@DPDiaSidebarHeader;
    [sidebar addSubview:header];[window.contentView addSubview:sidebar];
    native=NSMakeRect(234,6,760,688);page.frame=native;
    seamPadding=YES; page.frame=native;
    NSRect beforeMount=page.frame;
    NSCAssert(DPLibraryMount(controller),@"native vertical sidebar mounts");
    NSCAssert(NSEqualRects(DPRequestedFrame(page).rectValue,native) && NSEqualRects(page.frame,beforeMount),@"the first mounted frame preserves edge-to-edge padding before animation or native relayout can correct it");
    controller.expansion=.01; DPLibraryUpdateHosts(controller);
    NSCAssert(NSMinY(page.frame)==0 && NSHeight(page.frame)==700 && NSWidth(page.frame)==NSWidth(beforeMount),@"the first timed icon/shortcut reveal frame has no double inset");
    [window setContentSize:NSMakeSize(800,600)]; DPLibraryUpdateHosts(controller); DPLibraryUnmount(controller);
    NSCAssert(fabs(NSMaxX(page.frame)-800)<.5 && NSMinY(page.frame)==0 && NSHeight(page.frame)==600,@"real edge-only padding stays correct through resize and close");
    [window setContentSize:NSMakeSize(1000,700)]; seamPadding=NO; page.frame=native;
    NSCAssert(DPLibraryMount(controller),@"native vertical sidebar mounts before resize");
    controller.expansion=1;DPLibraryUpdateHosts(controller);
    [window setContentSize:NSMakeSize(800,600)];DPLibraryUpdateHosts(controller);
    NSCAssert(fabs(NSWidth(sidebar.frame)-480)<.5,@"resizing expanded sidebar still reserves page width");
    DPLibraryUnmount(controller);
    NSCAssert(fabs(NSWidth(sidebar.frame)-228)<.5 && fabs(NSMaxX(page.frame)-800)<.5,@"vertical sidebar and page restore without gaps after resize");
    NSCAssert(DPLibraryMount(controller),@"mount before native hide");controller.expansion=1;DPLibraryUpdateHosts(controller);
    sidebar.hidden=YES;
    NSCAssert(!controller.expanded && !controller.view.superview && fabs(NSMaxX(page.frame)-800)<.5,@"native sidebar hide immediately releases Library and page overrides");
    sidebar.hidden=NO;
    NSCAssert(DPLibraryMount(controller),@"mount before native slide-away");controller.expansion=1;DPLibraryUpdateHosts(controller);
    [sidebar setFrameOrigin:NSMakePoint(-228,0)];
    NSCAssert(!controller.expanded,@"native sidebar slide-away cannot leave Library geometry attached");
    [sidebar setFrameOrigin:NSZeroPoint];
    NSCAssert(DPLibraryMount(controller),@"mount before native window transfer");controller.expansion=1;DPLibraryUpdateHosts(controller);
    NSWindow *other=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    [other.contentView addSubview:sidebar];
    NSCAssert(!controller.expanded && !controller.view.superview,@"moving a native host to another window releases its original Library");
    puts("PASS: native hide/unhide, slide-away/window transfer, native baseline preservation, repeated open/layout/close, resize and Edge-to-Edge toggling");
} }
