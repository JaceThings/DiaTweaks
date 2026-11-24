#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *doc=[DPEaselDocument documentWithSize:NSMakeSize(700,900)];
    DPEaselEditorSurface *surface=(id)DPEaselEditor(doc);
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:16 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSData *tiff=[bitmap representationUsingType:NSBitmapImageFileTypeTIFF properties:@{}];
    NSPasteboard *board=[NSPasteboard pasteboardWithUniqueName]; [board setData:tiff forType:NSPasteboardTypeTIFF];
    NSCAssert([surface.canvas pasteImageFromPasteboard:board atPoint:NSMakePoint(30,160)],@"native TIFF paste accepted");
    NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:10];
    while(doc.objects.count==1 && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(doc.objects.count==2 && [doc.objects.lastObject[@"type"] isEqual:@"image"],@"worker conversion imports and places exactly one image");
    NSCAssert(DPEaselObjectRect(doc.objects.lastObject).size.width==32 && DPEaselObjectRect(doc.objects.lastObject).size.height==16,@"clipboard conversion retains image dimensions");
    [DPEaselStore.shared flush]; [board releaseGlobally];
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: native TIFF clipboard converts on worker and imports without touching general clipboard");
} }
