#import "Patches/Easels/Canvas.h"
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static NSEvent *mouse(DPEaselCanvas *canvas,NSEventType type,NSPoint point) {
    return [NSEvent mouseEventWithType:type location:[canvas convertPoint:point toView:nil] modifierFlags:0 timestamp:0 windowNumber:canvas.window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; document.undo.groupsByEvent=NO;
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,900,1400)]; canvas.document=document;
    NSWindow *window=[[NSWindow alloc] initWithContentRect:canvas.bounds styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO; window.contentView=canvas;
    [canvas selectTool:@"text"];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(100,200))];
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(280,270))];
    NSCAssert(NSEqualRects(DPEaselObjectRect(canvas.draft),NSMakeRect(100,200,180,70)),@"text draft follows the dragged rectangle");
    [document.undo beginUndoGrouping]; [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(280,270))]; [document.undo endUndoGrouping];
    NSCAssert(canvas.textEditor && NSEqualRects(canvas.textEditor.frame,NSMakeRect(100,200,180,70)) && [canvas.tool isEqual:@"text"],@"drag places a text editor of the requested size and keeps its tool");
    NSBitmapImageRep *pixels=[canvas bitmapImageRepForCachingDisplayInRect:canvas.bounds]; [canvas cacheDisplayInRect:canvas.bounds toBitmapImageRep:pixels];
    CGFloat scaleX=pixels.pixelsWide/NSWidth(canvas.bounds), scaleY=pixels.pixelsHigh/NSHeight(canvas.bounds);
    NSUInteger colored=0;
    for(NSInteger y=190;y<205;y++) for(NSInteger x=90;x<285;x++) {
        NSColor *color=[[pixels colorAtX:round(x*scaleX) y:round(y*scaleY)] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        if(color.redComponent>.8 && color.greenComponent>.2 && color.greenComponent<.8 && color.blueComponent<.3) colored++;
    }
    NSCAssert(colored>50,@"active empty text editing retains its visible accent selection box");
    [canvas endText];
    for(NSString *tool in @[@"text",@"rectangle",@"oval"]) {
        [canvas selectTool:tool]; NSUInteger before=document.objects.count;
        [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(400,400))];
        [document.undo beginUndoGrouping]; [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(400,400))]; [document.undo endUndoGrouping];
        NSRect frame=DPEaselObjectRect(document.objects.lastObject);
        NSCAssert(document.objects.count==before+1 && frame.size.width>=120 && frame.size.height>=40,@"click places a usable preset text box or shape"); [canvas endText];
    }
    [canvas removeFromSuperview]; [window close]; [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: dragged text box geometry, visible editing outline, persistent text tool and click-to-place text/shape presets");
} }
