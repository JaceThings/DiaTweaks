#import "Patches/Easels/Portable.h"
#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static void waitFor(BOOL (^done)(void)) { NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:5]; while(!done() && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; NSCAssert(done(),@"portable operation completes"); }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselStore *store=DPEaselStore.shared; DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(1000,1400)]; [document rename:@"Portable <Test> नमस्ते"];
    // Deliberately asymmetric image catches flipped preview rendering.
    NSBitmapImageRep *pixels=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:2 pixelsHigh:2 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [pixels setColor:NSColor.redColor atX:0 y:0]; [pixels setColor:NSColor.blueColor atX:0 y:1];
    [pixels setColor:NSColor.redColor atX:1 y:0]; [pixels setColor:NSColor.blueColor atX:1 y:1];
    NSData *png=[pixels representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString *asset=NSUUID.UUID.UUIDString; NSDictionary *image=@{@"id":NSUUID.UUID.UUIDString,@"type":@"image",@"asset":asset,@"rect":@[@10,@300,@100,@100],@"z":@10,@"order":@10};
    [document replaceObjects:[document.objects arrayByAddingObject:image] action:@"Image"];
    NSURL *dir=[store assetURL:asset document:document.identifier].URLByDeletingLastPathComponent;
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil]; [png writeToURL:[store assetURL:asset document:document.identifier] atomically:YES];
    __block BOOL done=NO; __block NSError *error=nil;
    NSURL *file=[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"Roundtrip.easel"]];
    [store exportPortable:document editable:YES toURL:file completion:^(NSError *e){ error=e; done=YES; }]; waitFor(^BOOL{ return done; }); NSCAssert(!error,@"export succeeds");
    NSData *bytes=[NSData dataWithContentsOfURL:file]; NSDictionary *decoded=DPEaselReadPortable(bytes,&error); NSCAssert(decoded && [decoded[@"assets"][asset] isEqual:png],@"original raster bytes survive editable export");
    NSString *html=[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding]; NSCAssert([html containsString:@"prefers-color-scheme: dark"] && [html containsString:@"Portable &lt;Test&gt;"] && ![html containsString:root],@"HTML escapes titles and excludes local paths");
    NSString *prefix=@"src=\"data:image/png;base64,"; NSRange imageStart=[html rangeOfString:prefix]; NSUInteger offset=NSMaxRange(imageStart);
    NSRange imageEnd=[html rangeOfString:@"\"" options:0 range:NSMakeRange(offset,html.length-offset)];
    NSData *previewBytes=[[NSData alloc] initWithBase64EncodedString:[html substringWithRange:NSMakeRange(offset,imageEnd.location-offset)] options:0];
    NSBitmapImageRep *render=[NSBitmapImageRep imageRepWithData:previewBytes];
    NSColor *top=[[render colorAtX:40 y:640] colorUsingColorSpace:NSColorSpace.sRGBColorSpace],*bottom=[[render colorAtX:40 y:760] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    NSCAssert(top.redComponent>.8 && bottom.blueComponent>.8,@"portable preview keeps images upright at their logical positions");
    done=NO; __block DPEaselDocument *copy=nil; [store importPortableURL:file profile:@"Profile 6" completion:^(DPEaselDocument *d,NSError *e){ copy=d; error=e; done=YES; }]; waitFor(^BOOL{ return done; });
    NSCAssert([copy.profile isEqual:@"Profile 6"],@"import assigns the recipient profile rather than inheriting sender ownership");
    NSCAssert(copy && !error && ![copy.identifier isEqual:document.identifier] && [copy.objects isEqual:document.objects],@"imports preserve objects with independent identity");
    [copy rename:@"Independent"]; NSCAssert(![copy.title isEqual:document.title],@"editing copy cannot rename original");
    NSData *preview=DPEaselPortableHTML(document.snapshot,@{asset:png},png,png,NO,&error); NSCAssert(preview && !DPEaselReadPortable(preview,nil),@"preview excludes editable model and cannot be imported as editable");
    NSCAssert(!DPEaselReadPortable([@"<script>malicious</script>" dataUsingEncoding:NSUTF8StringEncoding],nil),@"unrecognized files are rejected, never executed");
    NSData *missing=DPEaselPortableHTML(document.snapshot,@{},png,png,YES,nil); NSCAssert(!DPEaselReadPortable(missing,nil),@"missing image assets reject complete import rather than creating placeholders");
    NSDictionary *invalid=@{asset:[@"not an image" dataUsingEncoding:NSUTF8StringEncoding]}; NSData *bad=DPEaselPortableHTML(document.snapshot,invalid,png,png,YES,nil); NSCAssert(!DPEaselReadPortable(bad,nil),@"invalid raster data is rejected");
    [store flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil]; puts("PASS: portable editable/preview export, independent import, embedded assets, escaped titles, malformed/missing asset rejection");
} }
