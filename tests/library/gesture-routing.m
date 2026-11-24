#import "Patches/SidebarLibrary/Gesture.h"
DPPatch DPSidebarLibrary;
static DPLibraryController *current;
static BOOL first = YES, settled, target;
@implementation DPLibraryController @end
@interface GestureWindow : NSWindow
@property NSMutableArray *received;
@end
@implementation GestureWindow
- (void)sendEvent:(NSEvent *)event { [self.received addObject:event]; }
@end
@interface GestureEvent : NSObject
@property NSWindow *window;
@property NSEventPhase phase, momentumPhase;
@property NSEventType type;
@property CGFloat scrollingDeltaX, scrollingDeltaY, deltaX;
@property NSTimeInterval timestamp;
@property NSPoint locationInWindow;
@end
@implementation GestureEvent @end
BOOL DPIsKind(id view,const char *name) { return [[view identifier] isEqual:@(name)]; }
NSView *DPFindView(NSView *root,BOOL (^test)(NSView *)) { if(test(root))return root;for(NSView *child in root.subviews){NSView *match=DPFindView(child,test);if(match)return match;}return nil; }
BOOL DPLibraryAtFirstSpace(NSWindow *window) { return first; }
DPLibraryController *DPLibraryForWindow(NSWindow *window) { return current; }
DPLibraryController *DPLibraryBeginInteraction(NSWindow *window) {
    if (!current) { current=[DPLibraryController new];current.expandedWidth=510; }
    current.expanded=YES;current.interacting=YES;current.sidebarHost=window.contentView.subviews.firstObject;return current;
}
void DPLibraryUpdateHosts(DPLibraryController *controller) {}
void DPLibraryAnimate(DPLibraryController *controller,BOOL opening) { settled=YES;target=opening;controller.interacting=NO;controller.expanded=opening;controller.expansion=opening?1:0; }
void DPLibraryToggle(NSWindow *window) {}
static NSEvent *event(GestureWindow *window,NSEventPhase phase,CGFloat x,CGFloat y,double time) {
    GestureEvent *e=[GestureEvent new];e.window=window;e.phase=phase;e.type=NSEventTypeScrollWheel;e.scrollingDeltaX=x;e.scrollingDeltaY=y;e.timestamp=time;e.locationInWindow=NSMakePoint(20,20);return (NSEvent *)e;
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];DPSidebarLibrary.on=YES;
    GestureWindow *window=[[GestureWindow alloc] initWithContentRect:NSMakeRect(0,0,600,500) styleMask:0 backing:NSBackingStoreBuffered defer:NO];window.received=[NSMutableArray new];
    NSView *host=[[NSView alloc] initWithFrame:NSMakeRect(0,0,217,500)],*header=[NSView new];header.identifier=@DPDiaSidebarHeader;[host addSubview:header];[window.contentView addSubview:host];
    DPLibraryGesture *g=[DPLibraryGesture new];
    NSCAssert(!DPLibraryRouteScroll(event(window,NSEventPhaseBegan,0,0,1),g),@"hold prefix at Library edge");
    NSCAssert(!DPLibraryRouteScroll(event(window,NSEventPhaseChanged,102,0,1.02),g),@"claim continuous swipe");
    NSCAssert(fabs(current.expansion-.2)<.001 && !settled,@"partial swipe follows distance without triggering settlement");
    NSCAssert(!DPLibraryRouteScroll(event(window,NSEventPhaseChanged,0,0,1.3),g) && fabs(current.expansion-.2)<.001 && !settled,@"stationary finger holds partial progress");
    DPLibraryRouteScroll(event(window,NSEventPhaseChanged,-51,0,1.32),g);
    NSCAssert(fabs(current.expansion-.1)<.001 && !settled,@"reverse follows finger");
    DPLibraryRouteScroll(event(window,NSEventPhaseCancelled,0,0,1.4),g);
    NSCAssert(settled && !target && !current.expanded,@"cancel restores closed start");
    NSEvent *momentum=event(window,NSEventPhaseNone,12,0,1.5);((GestureEvent *)momentum).momentumPhase=NSEventPhaseChanged;
    NSCAssert(!DPLibraryRouteScroll(momentum,g),@"consume claimed momentum");
    settled=NO;[window.received removeAllObjects];
    NSEvent *begin=event(window,NSEventPhaseBegan,0,0,2),*prefix=event(window,NSEventPhaseChanged,-2,0,2.01),*next=event(window,NSEventPhaseChanged,-5,0,2.02);
    DPLibraryRouteScroll(begin,g);DPLibraryRouteScroll(prefix,g);
    NSCAssert((DPLibraryRouteScroll(next,g)==next && [window.received isEqual:@[begin,prefix]]),@"ordinary space swipe receives original prefix in order");
    NSCAssert(!settled,@"ordinary space swipe never mounts Library");
    [window.received removeAllObjects];begin=event(window,NSEventPhaseBegan,0,0,3);next=event(window,NSEventPhaseChanged,0,8,3.02);
    DPLibraryRouteScroll(begin,g);NSCAssert(DPLibraryRouteScroll(next,g)==next && [window.received isEqual:@[begin]],@"vertical scrolling retains native Began");
    first=NO;begin=event(window,NSEventPhaseBegan,0,0,4);NSCAssert(DPLibraryRouteScroll(begin,g)==begin,@"non-first space remains native");
    first=YES;current.expanded=YES;current.expansion=1;settled=NO;
    DPLibraryRouteScroll(event(window,NSEventPhaseBegan,0,0,5),g);DPLibraryRouteScroll(event(window,NSEventPhaseChanged,-255,0,5.02),g);
    NSCAssert(fabs(current.expansion-.5)<.001 && !settled,@"close follows distance");
    DPLibraryRouteScroll(event(window,NSEventPhaseChanged,127.5,0,5.04),g);NSCAssert(fabs(current.expansion-.75)<.001,@"closing reverses smoothly");
    DPLibraryRouteScroll(event(window,NSEventPhaseCancelled,0,0,5.1),g);NSCAssert(target && current.expanded,@"cancel restores open start");
    current.expanded=NO;current.expansion=0;settled=NO;
    DPLibraryRouteScroll(event(window,NSEventPhaseBegan,0,0,6),g);DPLibraryRouteScroll(event(window,NSEventPhaseChanged,720,0,6.02),g);
    NSCAssert(current.expansion==1,@"overswipe stops at open edge");
    DPLibraryRouteScroll(event(window,NSEventPhaseChanged,-51,0,6.04),g);
    NSCAssert(fabs(current.expansion-.9)<.001,@"reverse from overswiped edge moves immediately");
    DPLibraryRouteScroll(event(window,NSEventPhaseChanged,-720,0,6.06),g);
    NSCAssert(current.expansion==0,@"overswipe stops at closed edge");
    DPLibraryRouteScroll(event(window,NSEventPhaseChanged,51,0,6.08),g);
    NSCAssert(fabs(current.expansion-.1)<.001,@"reverse from closed edge moves immediately");
    DPLibraryRouteScroll(event(window,NSEventPhaseCancelled,0,0,6.1),g);
    // Horizontal tabs can own a Library host with no visible native header.
    header.hidden=YES; host.identifier=@"owned-horizontal-host"; current.sidebarHost=host;
    current.expanded=YES; current.expansion=1; settled=NO;
    DPLibraryRouteScroll(event(window,NSEventPhaseBegan,0,0,7),g);
    DPLibraryRouteScroll(event(window,NSEventPhaseChanged,-255,0,7.02),g);
    NSCAssert(g.active && fabs(current.expansion-.5)<.001,@"open Library consumes continuous gestures through its owned horizontal host without a native sidebar header");
    DPLibraryRouteScroll(event(window,NSEventPhaseCancelled,0,0,7.04),g);
    NSCAssert(target && current.expanded,@"owned horizontal host cancellation restores the open Library");
    puts("PASS: continuous partial/reversed/cancelled and edge-overtravel swipes, momentum, native event prefixes and non-first-space isolation");
} }
