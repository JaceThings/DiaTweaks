#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static NSEvent *mouse(DPEaselCanvas *canvas,NSEventType type,NSPoint point) {
    return [NSEvent mouseEventWithType:type location:[canvas convertPoint:point toView:nil] modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:1 clickCount:1 pressure:1];
}
@interface ShapeFixtureWindow : NSWindow
@property BOOL pointerInside;
@property NSPoint pointer;
@end
@implementation ShapeFixtureWindow
- (BOOL)isKeyWindow { return YES; }
- (NSPoint)mouseLocationOutsideOfEventStream { return self.pointerInside ? self.pointer : NSMakePoint(-10000,-10000); }
@end
int main(void) { @autoreleasepool {
    NSString *domain=[@"com.diapatches.easel-shape-test." stringByAppendingString:NSUUID.UUID.UUIDString];
    setenv("DIATWEAKS_DOMAIN",domain.UTF8String,1);
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; document.undo.groupsByEvent=NO;
    DPEaselEditorSurface *surface=(id)DPEaselEditor(document); surface.frame=NSMakeRect(0,0,900,700); [surface layoutSubtreeIfNeeded];
    ShapeFixtureWindow *window=[[ShapeFixtureWindow alloc] initWithContentRect:surface.frame styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO; window.contentView=surface;
    DPEaselCanvas *canvas=surface.canvas;
    NSCAssert(!DPEaselShapeOutline(@"oval") && !DPEaselShapeOutline(@"rectangle"),@"new users start with filled shapes");
    [canvas selectTool:@"oval"];
    NSCAssert(surface.shapeOptions.subviews.count==2 && NSHeight(surface.shapeOptions.frame)>NSWidth(surface.shapeOptions.frame),@"shape tool opens a detached vertical two-option palette");
    NSButton *outline=surface.shapeOptions.subviews.lastObject; [surface chooseShapeStyle:outline];
    NSCAssert(outline.state && DPEaselShapeOutline(@"oval") && !DPEaselShapeOutline(@"rectangle"),@"selection state and defaults are independent per shape");
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(100,300))];
    NSCAssert(!surface.shapeOptions && [canvas.draft[@"outline"] boolValue],@"drawing immediately dismisses options and uses the chosen outline style");
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(250,420))];
    [document.undo beginUndoGrouping]; [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(250,420))]; [document.undo endUndoGrouping];
    NSCAssert([document.objects.lastObject[@"outline"] boolValue] && [canvas.tool isEqual:@"oval"] && !surface.shapeOptions,@"completed shape keeps its tool active without reopening the drawing options");
    NSString *identifier=document.objects.lastObject[@"id"];
    [canvas selectTool:@"select"]; [canvas.selection addObject:identifier]; [surface updateShapeOptions];
    NSButton *filled=surface.shapeOptions.subviews.firstObject;
    [document.undo beginUndoGrouping]; [surface chooseShapeStyle:filled]; [document.undo endUndoGrouping];
    NSCAssert(![document.objects.lastObject[@"outline"] boolValue],@"selected existing shape can change back to filled");
    [document.undo undo]; NSCAssert([document.objects.lastObject[@"outline"] boolValue],@"style change is a single undoable action");
    DPEaselRememberShapeOutline(@"oval",YES);
    DPEaselEditorSurface *second=(id)DPEaselEditor(document); [second.canvas selectTool:@"oval"];
    NSCAssert([(NSButton *)second.shapeOptions.subviews.lastObject state],@"a new editor remembers the previous outline default");
    window.pointer=[surface.shapeOptions convertPoint:NSMakePoint(20,20) toView:nil]; window.pointerInside=YES;
    NSDate *until=[NSDate dateWithTimeIntervalSinceNow:3.7];
    while(until.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(surface.shapeOptions && !second.shapeOptions,@"hovered shape options stay open while idle options dismiss");
    window.pointerInside=NO; until=[NSDate dateWithTimeIntervalSinceNow:3.7];
    while(until.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(!surface.shapeOptions,@"shape options dismiss after pointer leaves");
    [second.canvas selectTool:@"oval"];
    NSCAssert(second.shapeOptions.subviews.count==2,@"choosing the same tool again reopens its options after the timeout");
    [second hideShapeOptions]; [surface removeFromSuperview]; [window close];
    [DPEaselStore.shared flush]; [[[NSUserDefaults alloc] initWithSuiteName:domain] removePersistentDomainForName:domain];
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: filled/outline defaults, independent remembered tools, contextual editing/undo and dismissal on draw/timeout");
} }
