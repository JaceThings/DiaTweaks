#import "Patches/SidebarLibrary/Library.h"
void DPLibraryRememberWindowContext(NSWindow *,NSString *);
NSString *DPLibraryResolveWindowContext(NSWindow *,NSString *);
NSString *DPIDKey(id value) { return [value isKindOfClass:NSString.class] ? value : nil; }
NSString *DPLibraryDirectoryForName(NSString *name) { return @{@"First Profile":@"Profile 1",@"Second Profile":@"Profile 6"}[name]; }
id DPSwiftValue(id object,NSString *key) { return [object valueForKey:key]; }
@interface LibraryScriptProfile : NSObject
@property NSString *spaceID,*name;
@end
@implementation LibraryScriptProfile @end
@interface LibraryScriptWindow : NSObject
@property NSString *windowId;
@property LibraryScriptProfile *activeProfile;
@end
@implementation LibraryScriptWindow @end
@interface LibraryScriptApp : NSObject
@property NSArray *appleScriptWindows;
@end
@implementation LibraryScriptApp @end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    LibraryScriptApp *app = [LibraryScriptApp new]; NSApp.delegate = (id)app;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    window.identifier = @"fixture-window";
    LibraryScriptWindow *facade = [LibraryScriptWindow new]; facade.windowId = window.identifier;
    facade.activeProfile = [LibraryScriptProfile new]; facade.activeProfile.spaceID = @"space-a";
    app.appleScriptWindows = @[facade];
    NSCAssert([DPLibraryResolveWindowContext(window,@"personal") isEqual:@"personal"],@"initial space resolved");
    facade.activeProfile.spaceID = @"space-b"; DPLibraryRememberWindowContext(window,@"work");
    NSCAssert([DPLibraryResolveWindowContext(window,@"work") isEqual:@"work"],@"new space uses attached context");
    facade.activeProfile.spaceID = @"space-a";
    DPLibraryRememberWindowContext(window,@"work");
    NSCAssert([DPLibraryResolveWindowContext(window,@"work") isEqual:@"personal"],@"returning space ignores stale attachment");
    NSWindow *second = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    second.identifier = @"fixture-second-window";
    LibraryScriptWindow *other = [LibraryScriptWindow new]; other.windowId = second.identifier;
    other.activeProfile = [LibraryScriptProfile new]; other.activeProfile.spaceID = @"space-a";
    app.appleScriptWindows = @[facade,other];
    NSCAssert([DPLibraryResolveWindowContext(second,@"second-context") isEqual:@"second-context"],@"same space key cannot borrow another window's mapping");
    NSCAssert([DPLibraryResolveWindowContext(window,@"work") isEqual:@"personal"],@"second window leaves first window mapping intact");
    facade.activeProfile.spaceID=@"first-space"; facade.activeProfile.name=@"First Profile";
    NSCAssert([DPLibraryResolveWindowContext(window,@"Profile 6") isEqual:@"Profile 1"],@"active native name resolves a new space despite wrong first attachment");
    DPLibraryRememberWindowContext(window,@"Profile 6");
    NSCAssert([DPLibraryResolveWindowContext(window,@"Profile 6") isEqual:@"Profile 1"],@"an old attachment cannot override the first profile");
    facade.activeProfile.spaceID=@"second-space"; facade.activeProfile.name=@"Second Profile";
    NSCAssert([DPLibraryResolveWindowContext(window,@"Profile 1") isEqual:@"Profile 6"],@"new demo space resolves its own download and archive directory");
    facade.activeProfile.spaceID=@"unknown-duplicate-space"; facade.activeProfile.name=@"Duplicate";
    NSCAssert(DPLibraryResolveWindowContext(window,@"Profile 1")==nil,@"ambiguous named profiles fail closed instead of borrowing files");
    facade.activeProfile = nil;
    NSCAssert(DPLibraryResolveWindowContext(window,@"work") == nil,@"unresolved active space fails closed");
    puts("PASS: stable space identity, return after reused browser, unresolved-space isolation");
} }
