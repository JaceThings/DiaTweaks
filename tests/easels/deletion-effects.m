#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
static NSUInteger effects;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.controlAccentColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
void DPLibraryDissolve(NSArray<NSView *> *views,void (^completion)(void)) {
    effects++;
    completion();
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(300,300)];
    NSDictionary *red=@{@"id":NSUUID.UUID.UUIDString,@"type":@"rectangle",@"rect":@[@40,@40,@80,@80],@"color":@[@1,@0,@0,@1],@"order":@1,@"z":@1};
    NSDictionary *blue=@{@"id":NSUUID.UUID.UUIDString,@"type":@"rectangle",@"rect":@[@80,@60,@80,@80],@"color":@[@0,@0,@1,@1],@"order":@2,@"z":@2};
    document.undo.groupsByEvent=NO;
    [document.undo disableUndoRegistration]; [document replaceObjects:@[red,blue] action:@"Fixture"]; [document.undo enableUndoRegistration];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,300,300) styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO;
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,300,300)]; canvas.document=document; window.contentView=canvas;
    [canvas.selection addObject:red[@"id"]]; document.undo.groupsByEvent=NO;
    [document.undo beginUndoGrouping]; [canvas delete:nil]; [document.undo endUndoGrouping];
    NSCAssert(effects==0 && document.objects.count==1 && [document.objects.firstObject isEqual:blue],@"deletion commits immediately and keeps neighbors");
    NSCAssert(canvas.subviews.count==0,@"snapshot surface is removed immediately");
    [document.undo undo]; NSCAssert([[document.objects valueForKey:@"id"] containsObject:red[@"id"]] && [[document.objects valueForKey:@"id"] containsObject:blue[@"id"]],@"instant deletion preserves Undo");
    [canvas removeFromSuperview]; [window close]; [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: instant canvas deletion without dust, preserved neighbors and Undo");
} }
