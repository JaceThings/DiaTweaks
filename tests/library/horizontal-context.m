#import "Patches/SidebarLibrary/Library.h"
DPPatch DPSidebarLibrary={.on=YES};
BOOL DPLibraryHandleStripContextMenu(NSEvent *event);
static NSUInteger forwarded;
NSView *DPFindView(NSView *root,BOOL (^test)(NSView *)) {
    if(test(root)) return root;
    for(NSView *child in root.subviews) { NSView *match=DPFindView(child,test); if(match) return match; }
    return nil;
}
BOOL DPIsKind(id object,const char *name) { return [[object identifier] isEqual:@(name)]; }
@interface NativePlusFixture : NSButton @end
@implementation NativePlusFixture
- (void)rightMouseDown:(NSEvent *)event { forwarded++; }
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,900,600) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSView *strip=[[NSView alloc] initWithFrame:NSMakeRect(0,0,900,42)]; strip.identifier=@(DPDiaTabStrip); [window.contentView addSubview:strip];
    NativePlusFixture *plus=[[NativePlusFixture alloc] initWithFrame:NSMakeRect(800,0,32,32)]; plus.accessibilityIdentifier=@"tabStripNewTabButton"; [strip addSubview:plus];
    NSEvent *event=[NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:NSMakePoint(500,20) modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
    NSCAssert(DPLibraryHandleStripContextMenu(event) && forwarded==1,@"blank strip forwards to native plus right-click handler");
    NSButton *control=[[NSButton alloc] initWithFrame:NSMakeRect(480,0,40,40)]; [strip addSubview:control];
    NSCAssert(!DPLibraryHandleStripContextMenu(event) && forwarded==1,@"existing controls retain their own native context menus"); [control removeFromSuperview];
    plus.hidden=YES; NSCAssert(!DPLibraryHandleStripContextMenu(event),@"hidden native menu source is never used"); plus.hidden=NO;
    DPSidebarLibrary.on=NO; NSCAssert(!DPLibraryHandleStripContextMenu(event),@"disabled patch leaves native context routing unchanged");
    DPSidebarLibrary.on=YES; [plus removeFromSuperview]; NSCAssert(!DPLibraryHandleStripContextMenu(event),@"missing native plus preserves native fallback");
    puts("PASS: blank horizontal strip uses native plus handler; existing controls, disabled and hidden sources remain untouched");
} }
