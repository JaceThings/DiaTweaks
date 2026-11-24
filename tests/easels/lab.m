#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    root=[NSTemporaryDirectory() stringByAppendingPathComponent:@"DiaTweaks-EaselLab"];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(1000,1300)];
    NSMutableDictionary *heading=[document.objects[0] mutableCopy]; heading[@"text"]=@"Native Easel"; heading[@"placeholder"]=@NO;
    NSDictionary *note=DPEaselText(@"Images, notes and drawings.\nA native canvas, saved locally.",NSMakeRect(95,220,420,100),1,NO);
    NSDictionary *shape=@{@"id":NSUUID.UUID.UUIDString,@"type":@"oval",@"order":@2,@"z":@2,@"rect":@[@560,@230,@220,@140],@"color":@[@1,@.63,@.25,@1]};
    [document replaceObjects:@[heading,note,shape] action:@"Demo"];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(100,100,1000,720) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    window.title=@"Easel Lab — isolated native editor"; window.releasedWhenClosed=NO;
    window.contentView=DPEaselEditor(document); [window center]; [window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
} }
