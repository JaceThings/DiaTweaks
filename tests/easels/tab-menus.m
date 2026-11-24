#import "Patches/Easels/HostInternal.h"
DPPatch DPEasels={.on=YES};
static NSString *root,*owned;
static NSUInteger deletions;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
NSString *DPEaselIdentifierForTabRow(NSView *row,NSWindow *window) { return [row.identifier isEqual:@"owned"] ? owned : nil; }
void DPEaselDeleteFromTab(NSWindow *window,DPEaselDocument *document) { if([document.identifier isEqual:owned]) deletions++; }
#import "Patches/Easels/TabMenus.m"
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1200)]; owned=document.identifier;
    [DPEaselStore.shared save:document completion:nil]; [DPEaselStore.shared flush];
    DPEaselInstallTabMenus();
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,900,700) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSView *row=NSView.new; row.identifier=@"owned"; [window.contentView addSubview:row];
    NSMenu *menu=NSMenu.new;
    NSMenuItem *rename=[menu addItemWithTitle:@"Rename…" action:@selector(description) keyEquivalent:@""];
    NSMenuItem *close=[menu addItemWithTitle:@"Close" action:@selector(description) keyEquivalent:@"w"];
    NSMenuItem *link=[menu addItemWithTitle:@"Copy Link" action:@selector(description) keyEquivalent:@""];
    NSMenuItem *markdown=[menu addItemWithTitle:@"Copy Link as Markdown" action:@selector(description) keyEquivalent:@""]; markdown.hidden=YES;
    DPConfigureTabMenu(menu,row);
    NSCAssert([menu itemWithTitle:@"Rename Easel…"] && [menu itemWithTitle:@"Delete Easel"],@"owned native tab exposes heading rename and stored-board delete");
    NSCAssert([close.title isEqual:@"Remove Easel from Sidebar"] && close.action==@selector(description) && [close.keyEquivalent isEqual:@"w"],@"remove placement retains native close action and keyboard equivalent");
    NSCAssert(link.hidden && markdown.hidden,@"local boards do not advertise a transferable public link");
    NSMenuItem *delete=[menu itemWithTitle:@"Delete Easel"]; ((void (*)(id,SEL,id))objc_msgSend)(delete.target,delete.action,delete);
    NSCAssert(deletions==1,@"Delete targets the stored board identity");
    [NSNotificationCenter.defaultCenter postNotificationName:NSMenuDidEndTrackingNotification object:menu];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.03]];
    NSCAssert([menu.itemArray containsObject:rename] && [close.title isEqual:@"Close"] && !link.hidden && markdown.hidden && menu.numberOfItems==4,@"native menu items and original visibility return after tracking");
    row.identifier=@"ordinary"; DPConfigureTabMenu(menu,row);
    NSCAssert(menu.numberOfItems==4 && ![menu itemWithTitle:@"Delete Easel"],@"ordinary tab menus remain untouched");
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: native Easel rename/delete/remove distinction, correct identity, scoped link behavior and menu restoration");
} }
