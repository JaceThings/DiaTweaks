#import "Patches/Easels/HostInternal.h"
NSString *DPLibraryContextForWindow(NSWindow *window) { return @"Profile 1"; }
#import "Commands/GroupTabs/GroupTabs.h"
DPPatch DPEasels={.on=YES};
static NSString *root; static id browser;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
id DPBrowserOfWindow(NSWindow *window) { return browser; }
NSArray *DPTrackedContents(id value) { return @[]; }
NSView *DPFindView(NSView *view,BOOL (^test)(NSView *)) { return nil; }
BOOL DPIsKind(id object,const char *name) { return NO; }
NSRect DPLibraryNativeFrame(NSView *view) { return view.frame; }
@interface OpenIdentity:NSObject @end
@implementation OpenIdentity
- (BOOL)isIncognito { return NO; }
@end
@interface OpenContext:NSObject
@property id id;
@end
@implementation OpenContext @end
@interface OpenBrowser:NSObject
@property id context;
@end
@implementation OpenBrowser @end
@interface OpenWindow:NSObject
@property NSString *windowId;
@property NSArray *appleScriptTabs;
@property id activeTab;
@end
@implementation OpenWindow @end
@interface OpenTab:NSObject
@property id URL;
@property(weak) OpenWindow *owner;
@property NSUInteger focused;
@end
@implementation OpenTab
- (void)focus:(id)sender { self.focused++; self.owner.activeTab=self; }
@end
@interface OpenApplication:NSObject <NSApplicationDelegate>
@property NSArray *appleScriptWindows;
@end
@implementation OpenApplication @end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    OpenContext *context=OpenContext.new; context.id=OpenIdentity.new; OpenBrowser *host=OpenBrowser.new; host.context=context; browser=host;
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,900,700) styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO; window.identifier=@"easel-fixture";
    DPEaselDocument *one=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)],*two=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)];
    [DPEaselStore.shared save:one completion:nil]; [DPEaselStore.shared save:two completion:nil]; [DPEaselStore.shared flush];
    OpenWindow *facade=OpenWindow.new; facade.windowId=window.identifier;
    OpenTab *a=OpenTab.new,*b=OpenTab.new; a.URL=[DPEaselStore.shared pageURL:one.identifier]; b.URL=[DPEaselStore.shared pageURL:two.identifier].absoluteString; a.owner=b.owner=facade;
    facade.appleScriptTabs=@[a,b]; facade.activeTab=a;
    OpenApplication *application=OpenApplication.new; application.appleScriptWindows=@[facade]; id old=NSApp.delegate; NSApp.delegate=application;
    NSCAssert(DPEaselOpen(window,two) && facade.activeTab==b && b.focused==1 && a.focused==0,@"opening an existing Easel focuses its exact native placement, accepting string URLs");
    NSCAssert(DPEaselOpen(window,one) && facade.activeTab==a && a.focused==1 && facade.appleScriptTabs.count==2,@"switching back focuses the existing tab without creating a duplicate");
    NSApp.delegate=old; [window close]; [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: existing Easel placements focus correctly in either direction without duplicate tabs");
} }
