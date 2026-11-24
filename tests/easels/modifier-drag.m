#import "Patches/Easels/Canvas.h"
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static NSEvent *mouse(DPEaselCanvas *canvas,NSEventType type,NSPoint point,NSEventModifierFlags flags) {
    return [NSEvent mouseEventWithType:type location:[canvas convertPoint:point toView:nil] modifierFlags:flags timestamp:0 windowNumber:canvas.window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; document.undo.groupsByEvent=NO;
    NSDictionary *shape=@{@"id":NSUUID.UUID.UUIDString,@"type":@"rectangle",@"rect":@[@100,@200,@100,@100],@"order":@1,@"z":@1};
    NSDictionary *image=@{@"id":NSUUID.UUID.UUIDString,@"type":@"image",@"asset":NSUUID.UUID.UUIDString,@"rect":@[@400,@200,@200,@100],@"order":@2,@"z":@2};
    [document.undo disableUndoRegistration]; [document replaceObjects:[document.objects arrayByAddingObjectsFromArray:@[shape,image]] action:@"Fixture"]; [document.undo enableUndoRegistration];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,900,700) styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO;
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,900,1400)]; canvas.document=document; window.contentView=canvas;
    [canvas.selection addObject:shape[@"id"]];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(150,250),NSEventModifierFlagOption)];
    NSCAssert(document.objects.count==3 && !canvas.duplicatingSelection,@"Option click alone does not duplicate");
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(180,270),NSEventModifierFlagOption)];
    NSCAssert(canvas.duplicatingSelection && canvas.previewObjects.count==4 && document.objects.count==3,@"duplicate remains a transient gesture until release");
    [document.undo beginUndoGrouping]; [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(180,270),NSEventModifierFlagOption)]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.count==4 && ![document.objects.lastObject[@"id"] isEqual:shape[@"id"]] && DPEaselObjectRect(document.objects.lastObject).origin.x==130 && [document.objects[1] isEqual:shape],@"Option drag commits an independent moved copy and preserves original");
    [document.undo undo]; NSCAssert(document.objects.count==3,@"one Undo reverses duplicate and movement together");
    [canvas.selection setSet:[NSSet setWithObject:image[@"id"]]];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(600,250),NSEventModifierFlagCommand)];
    NSCAssert(canvas.cropping,@"Command on an image edge enters crop mode");
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(550,250),NSEventModifierFlagCommand)];
    NSDictionary *preview=canvas.previewObjects.lastObject;
    NSCAssert(DPEaselObjectRect(preview).size.width==150 && fabs([preview[@"crop"][2] doubleValue]-.75)<.001 && [preview[@"asset"] isEqual:image[@"asset"]],@"edge cropping changes frame/source fractions without changing asset bytes");
    [document.undo beginUndoGrouping]; [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(550,250),NSEventModifierFlagCommand)]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.lastObject[@"crop"] && DPEaselValidSnapshot(document.snapshot),@"crop is persisted in the valid document model");
    [document.undo undo]; NSCAssert(!document.objects.lastObject[@"crop"] && DPEaselObjectRect(document.objects.lastObject).size.width==200,@"crop Undo restores full image geometry");
    NSImage *raster=[[NSImage alloc] initWithSize:NSMakeSize(200,100)];
    NSRect source=DPEaselImageSourceRect(@{@"crop":@[@.25,@.1,@.5,@.6]},raster);
    NSCAssert(fabs(source.origin.x-50)<.001 && fabs(source.origin.y-30)<.001 && source.size.width==100 && source.size.height==60,@"crop source converts top-origin fractions to AppKit image coordinates");
    [canvas removeFromSuperview]; [window close]; [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: Option-drag independent copies/Undo and Command-edge nondestructive image cropping/Undo");
} }
