#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.controlAccentColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static NSString *import(NSURL *url,DPEaselDocument *document) {
    __block NSString *asset=nil; __block BOOL done=NO;
    [DPEaselStore.shared importImage:url document:document completion:^(NSString *value,NSSize size,NSError *error){ NSCAssert(value && !error,@"fixture import succeeds"); asset=value; done=YES; }];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while(!done && deadline.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
    NSCAssert(done,@"bounded import completion"); return asset;
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSURL *source=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    NSBitmapImageRep *pixels=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:8 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [[pixels representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToURL:source atomically:YES];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; document.undo.groupsByEvent=NO;
    [DPEaselStore.shared save:document completion:nil]; [DPEaselStore.shared flush];
    NSView *container=[[NSView alloc] initWithFrame:NSMakeRect(0,0,900,700)];
    DPEaselEditorSurface *surface=(id)DPEaselEditor(document); [container addSubview:surface];
    NSUInteger generation=surface.canvas.importGeneration;
    NSString *abandoned=import(source,document); NSURL *abandonedURL=[DPEaselStore.shared assetURL:abandoned document:document.identifier];
    [surface.canvas selectTool:@"rectangle"];
    [surface completeImageImport:abandoned size:NSMakeSize(16,8) error:nil document:document generation:generation];
    [DPEaselStore.shared flush];
    NSCAssert([surface.canvas.tool isEqual:@"rectangle"] && !surface.canvas.pendingAsset && document.objects.count==1 && ![NSFileManager.defaultManager fileExistsAtPath:abandonedURL.path],@"late picker result cannot steal the new tool or leave a copied orphan");
    NSString *pending=import(source,document); NSURL *pendingURL=[DPEaselStore.shared assetURL:pending document:document.identifier];
    [surface completeImageImport:pending size:NSMakeSize(16,8) error:nil document:document generation:surface.canvas.importGeneration];
    NSCAssert([surface.canvas.tool isEqual:@"image"] && [surface.canvas.pendingAsset isEqual:pending],@"current result enters image placement");
    NSEvent *escape=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"\033" charactersIgnoringModifiers:@"\033" isARepeat:NO keyCode:53];
    [surface.canvas keyDown:escape]; [DPEaselStore.shared flush];
    NSCAssert(!surface.canvas.pendingAsset && [surface.canvas.tool isEqual:@"select"] && document.objects.count==1 && ![NSFileManager.defaultManager fileExistsAtPath:pendingURL.path],@"Escape cancels placement and removes only its uncommitted copied bytes");
    NSString *kept=import(source,document); NSURL *keptURL=[DPEaselStore.shared assetURL:kept document:document.identifier];
    [surface completeImageImport:kept size:NSMakeSize(16,8) error:nil document:document generation:surface.canvas.importGeneration];
    [document.undo beginUndoGrouping]; [surface.canvas placeImage:kept size:NSMakeSize(16,8) atPoint:NSMakePoint(30,180)]; [document.undo endUndoGrouping];
    [document.undo beginUndoGrouping]; [surface.canvas delete:nil]; [document.undo endUndoGrouping];
    [surface.canvas selectTool:@"oval"]; [DPEaselStore.shared flush];
    NSCAssert([NSFileManager.defaultManager fileExistsAtPath:keptURL.path],@"tool changes never discard a previously committed asset needed for undo");
    [document.undo undo]; NSCAssert(document.objects.count==2,@"deleted committed image still restores through undo");
    [surface removeFromSuperview]; [DPEaselStore.shared flush];
    [NSFileManager.defaultManager removeItemAtURL:source error:nil]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: import generation, late-result cancellation, unplaced-byte cleanup and preservation of committed undo assets");
} }
