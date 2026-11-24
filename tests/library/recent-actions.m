#import "Patches/SidebarLibrary/Library.h"
DPPatch DPSidebarLibraryDust={.on=YES};
#import <objc/runtime.h>
NSView *DPLibraryRecentView(NSWindow *window);
static NSUInteger opens, menus;
BOOL DPLibraryHandleRecentContextMenu(NSEvent *event);
static void recordMenu(id self,SEL selector,id event) { menus++; }
static NSArray *files;
static NSString *space = @"fixture-space";
NSString *DPLibraryActiveSpace(NSWindow *window) { return space; }
id DPGet(id object,const void *key) { return objc_getAssociatedObject(object,key); }
void DPSet(id object,const void *key,id value) { objc_setAssociatedObject(object,key,value,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
void DPLibraryCheckRecentContext(NSWindow *window);
id DPLibraryContextForWindow(NSWindow *window) { return @"fixture"; }
NSArray *DPLibraryFiles(id context) { return files; }
void DPLibraryHideFiles(id context,NSArray *items) {}
void DPLibraryThumbnail(NSURL *url,void (^completion)(NSImage *)) { completion(nil); }
static void recordOpen(id self,SEL selector,id sender) { opens++; }
@interface ContextOwningRoot : NSView @end
@implementation ContextOwningRoot
- (NSView *)hitTest:(NSPoint)point { return NSPointInRect(point,self.frame) ? self : nil; }
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSString *path = @"/tmp/sidebar-library-recent-fixture.txt";
    [@"fixture" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    DPLibraryFile *file = [DPLibraryFile new]; file.identifier = @"fixture"; file.path = path; file.date = NSDate.date; file.state = 2;
    files = @[file];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,400,400) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    window.contentView=[[ContextOwningRoot alloc] initWithFrame:NSMakeRect(0,0,400,400)];
    NSView *card = DPLibraryRecentView(window); [window.contentView addSubview:card];
    NSView *row = card.subviews.firstObject;
    NSPoint point = [row convertPoint:NSMakePoint(20,20) toView:card];
    NSCAssert([row hitTest:point] == row,@"thumbnail child cannot intercept row clicks or menus");
    Method method = class_getInstanceMethod(row.class,NSSelectorFromString(@"open:"));
    IMP original = method_setImplementation(method,(IMP)recordOpen);
    NSPoint location = [row convertPoint:NSMakePoint(20,20) toView:nil];
    NSEvent *down = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:location modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
    NSEvent *up = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:location modifierFlags:0 timestamp:.1 windowNumber:window.windowNumber context:nil eventNumber:2 clickCount:1 pressure:0];
    @try {
        [row mouseDown:down]; NSCAssert(opens == 0,@"mouse down leaves room for dragging");
        [row mouseUp:up]; NSCAssert(opens == 1,@"single click opens once on release");
        [row setValue:@YES forKey:@"dragged"]; [row mouseUp:up]; NSCAssert(opens == 1,@"drag release cannot also open the file");
        NSMenu *menu = [row menuForEvent:up];
        NSCAssert(menu.numberOfItems == 5 && [menu itemWithTitle:@"Share…"] && [menu itemWithTitle:@"Hide from Library"],@"whole row offers file context actions");
        NSCAssert([row accessibilityPerformPress] && opens == 2,@"VoiceOver press opens the same file action");
        Method menuMethod=class_getInstanceMethod(row.class,@selector(rightMouseDown:));
        IMP menuOriginal=method_setImplementation(menuMethod,(IMP)recordMenu);
        NSEvent *right=[NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:location modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:3 clickCount:1 pressure:1];
        NSEvent *control=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:location modifierFlags:NSEventModifierFlagControl timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:4 clickCount:1 pressure:1];
        NSCAssert(DPLibraryHandleRecentContextMenu(right) && DPLibraryHandleRecentContextMenu(control) && menus==2,@"local routing claims right/control clicks before native sidebar handling");
        NSCAssert(!DPLibraryHandleRecentContextMenu(down),@"normal clicks keep their normal dispatch");
        NSEvent *outside=[NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:NSMakePoint(350,350) modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:5 clickCount:1 pressure:1];
        NSCAssert(!DPLibraryHandleRecentContextMenu(outside),@"native sidebar context clicks outside preview are untouched");
        NSView *cover=[[NSView alloc] initWithFrame:card.frame]; [window.contentView addSubview:cover positioned:NSWindowAbove relativeTo:card];
        NSCAssert(!DPLibraryHandleRecentContextMenu(right),@"a covering sibling keeps its own context routing");
        [cover removeFromSuperview]; card.hidden=YES;
        NSCAssert(!DPLibraryHandleRecentContextMenu(right),@"hidden card cannot claim native sidebar context clicks"); card.hidden=NO;
        method_setImplementation(menuMethod,menuOriginal);
        space = @"different-space"; DPLibraryCheckRecentContext(window);
        NSCAssert(!card.superview,@"space change dismisses old-profile recent downloads");
    } @finally { method_setImplementation(method,original); }
    puts("PASS: row hit testing, single-click open, drag suppression, context menu and accessibility press");
} }
