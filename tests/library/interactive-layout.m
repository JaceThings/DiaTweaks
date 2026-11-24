#import "Patches/SidebarLibrary/Library.h"
#import <objc/runtime.h>
@implementation DPLibraryController @end
id DPGet(id object,const void *key) { return objc_getAssociatedObject(object,key); }
void DPSet(id object,const void *key,id value) { objc_setAssociatedObject(object,key,value,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
BOOL DPIsKind(id view,const char *name) { return [[view identifier] isEqual:@(name)]; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSView *host=[[NSView alloc] initWithFrame:NSMakeRect(0,0,510,700)],*body=[[NSView alloc] initWithFrame:NSMakeRect(0,0,260,700)],*hidden=[NSView new],*header=[NSView new],*library=[[NSView alloc] initWithFrame:NSMakeRect(0,0,510,700)];
    hidden.hidden=YES;header.identifier=@DPDiaSidebarHeader;library.wantsLayer=YES;
    [host addSubview:body];[host addSubview:hidden];[host addSubview:header];[host addSubview:library];
    DPLibraryController *c=[DPLibraryController new];c.sidebarHost=host;c.view=library;c.expandedWidth=510;c.expanded=YES;c.interacting=YES;
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(96,60,406,500)]; scroll.drawsBackground=NO;
    [library addSubview:scroll];
    DPLibraryCoverTabs(c);
    for (NSNumber *value in @[@0.5,@0.25,@0.1,@0.8]) {
        c.expansion=value.doubleValue; [host setFrameSize:NSMakeSize(217+(510-217)*c.expansion,700)]; DPLibraryUpdateInteractiveLayout(c);
        // Simulate Dia rewriting its managed backing layer every layout pass.
        body.wantsLayer=YES; body.layer.transform=CATransform3DIdentity;
        DPLibraryUpdateInteractiveLayout(c);
        NSImageView *surface=nil;
        for (NSView *v in host.subviews) if ([v.identifier isEqual:@"DiaTweaks.SidebarLibrary.NativeSnapshot"]) surface=(id)v;
        NSCAssert(surface.image && !surface.hidden,@"native snapshot exists during transition");
        CGFloat edge=NSMaxX(library.frame);
        NSCAssert(fabs(edge-NSMinX(surface.frame))<.001,@"Library edge meets translated native tabs without a gap");
        NSCAssert(fabs(edge-510*c.expansion)<.001,@"surface movement follows swipe progress");
        NSCAssert(fabs(surface.alphaValue-(1-c.expansion))<.001 && fabs(surface.frame.origin.y-8*c.expansion)<.001,@"outgoing native tabs fade and sink subtly with the same gesture progress");
        NSCAssert(body.hidden && hidden.hidden && !header.hidden,@"native visibility is preserved during interaction");
        NSCAssert(CATransform3DIsIdentity(library.layer.transform),@"AppKit sees the actual reveal origin rather than an invisible layer-only translation");
        NSPoint right=[scroll convertPoint:NSMakePoint(NSWidth(scroll.bounds),50) toView:host];
        NSCAssert(right.x<=NSWidth(host.bounds) && fabs(right.x-(edge-8))<.001,@"scroll viewport right edge follows its real view origin, so cards cannot be trimmed using stale native coordinates");
        NSCAssert(NSWidth(scroll.frame)==406,@"reveal never shrinks the Easel scroll content to the partial sidebar width");
        NSCAssert(host.layer.masksToBounds,@"interactive content is clipped at host edge");
    }
    DPLibraryEndInteractiveLayout(c);
    NSCAssert(body.hidden && hidden.hidden,@"committed Library covers tabs");
    NSCAssert(!host.wantsLayer && CATransform3DIsIdentity(library.layer.transform),@"commit restores temporary layer ownership and transforms");
    c.expanded=NO;DPLibraryUncoverTabs(c);
    NSCAssert(!body.hidden && hidden.hidden,@"close restores original native visibility");
    c.expanded=YES;c.interacting=YES;c.expansion=.3;DPLibraryCoverTabs(c);DPLibraryUpdateInteractiveLayout(c);
    c.expanded=NO;DPLibraryEndInteractiveLayout(c);DPLibraryUncoverTabs(c);
    NSCAssert(!body.hidden && hidden.hidden && !host.wantsLayer && CATransform3DIsIdentity(library.layer.transform),@"cancel restores original visibility and geometry");
    puts("PASS: continuous joined-edge geometry, clipping, native visibility, commit and cancellation cleanup");
} }
