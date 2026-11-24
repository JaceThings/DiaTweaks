#import "Patches/Easels/LibraryUI.h"
NSString *DPLibraryContextForWindow(NSWindow *window) { return @"Profile 1"; }
#import "Patches/SidebarLibrary/Library.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
extern BOOL DPEaselFixtureDelayDust;
extern void (^DPEaselFixtureFinishDust)(void);
static BOOL testTasksEnabled=YES;
@interface FixtureTaskProvider : NSObject <DPLibrarySectionProvider> @end
@implementation FixtureTaskProvider
- (NSString *)title { return @"Tasks"; }
- (NSString *)symbol { return @"checklist"; }
- (NSInteger)sectionOrder { return 0; }
- (BOOL)isEnabled { return testTasksEnabled; }
- (NSView *)makeContent:(DPLibraryController *)controller { return NSView.new; }
- (void)reloadContent:(NSView *)content query:(NSString *)query {}
- (void)primaryAction:(DPLibraryController *)controller {}
@end
DPPatch DPSidebarLibraryDust={.on=YES};
static NSString *root;
static NSUInteger created;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
BOOL DPEaselCanCreate(NSWindow *window) { return DPEasels.on && window!=nil; }
BOOL DPEaselOpen(NSWindow *window,DPEaselDocument *document) { return document && !document.deleted; }
void DPEaselCreate(NSWindow *window) { created++; }
NSButton *DPLibraryMakeButton(NSString *title,NSString *symbol,id target,SEL action) { return [NSButton buttonWithTitle:title target:target action:action]; }
@implementation DPLibraryController
- (void)chooseSection:(NSButton *)button { self.section=DPLibrarySectionNames()[button.tag]; }
- (void)close {}
- (void)layout {
    self.scroll.frame=NSMakeRect(96,66,400,500); DPLibraryLayoutCustomSection(self);
}
@end
static void waitUntil(BOOL (^done)(void)) {
    NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:10];
    while(!done() && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(done(),@"catalog work completes");
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPLibraryRegisterSection(FixtureTaskProvider.new); DPEaselRegisterLibrary();
    NSCAssert(([DPLibrarySectionNames() isEqual:@[@"Tasks",@"Easels",@"Media",@"Downloads",@"Archived Tabs"]]),@"section order is stable even if Tasks registers before Easels");
    testTasksEnabled=NO;
    NSCAssert(([DPLibrarySectionNames() isEqual:@[@"Easels",@"Media",@"Downloads",@"Archived Tabs"]]),@"optional section precedes Media and Downloads");
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,510,700) styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO;
    DPLibraryController *controller=DPLibraryController.new; controller.window=window; controller.context=@"Profile 1"; controller.view=NSView.new; controller.rail=NSView.new;
    controller.search=NSSearchField.new; controller.scroll=NSScrollView.new; controller.section=@"Easels";
    [controller.view addSubview:controller.rail]; window.contentView=controller.view;
    DPLibraryBuildCategories(controller); NSCAssert(controller.rail.subviews.count==4,@"native rail contains four actual categories");
    NSCAssert(DPLibraryReloadCustomSection(controller),@"custom section owns only its content and header action");
    DPEaselLibraryContent *content=(id)controller.customContent;
    NSCAssert(controller.customHeaderButtons.count==2 && content.recovery.superview==controller.view && !content.recovery.title.length,@"Recently Deleted is an accessible header icon rather than bottom text");
    [DPEaselStore.shared flush]; [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    NSCAssert(!content.empty.hidden && !content.create.hidden && content.emptyIcon.image,@"empty collection has icon, explanation and create action");
    [content newEasel:nil]; NSCAssert(created==1,@"empty-state creation uses common create command");
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)];
    [DPEaselStore.shared save:document completion:nil];
    waitUntil(^BOOL { return content.records.count==1; });
    [content layoutSubtreeIfNeeded]; NSCAssert(content.grid.subviews.count==1,@"saved real document appears without polling");
    content.query=@"no matching title"; [content reload];
    NSCAssert(content.grid.subviews.count==0 && content.create.hidden && [content.empty.stringValue isEqual:@"No matching Easels"],@"search-empty state differs from empty collection");
    content.query=@""; [content reload]; [content layoutSubtreeIfNeeded];
    for(NSNumber *width in @[@410,@350,@414,@390]) {
        content.frame=NSMakeRect(96,66,width.doubleValue,500); [content layout];
        NSCAssert(fabs(NSWidth(content.grid.frame)-NSWidth(content.scroll.contentView.bounds))<.01,@"cards use the current clip viewport during reveal/resize, without a stale-width frame");
    }
    controller.context=@"Profile 6"; DPLibraryReloadCustomSection(controller);
    waitUntil(^BOOL { return content.loaded; }); [DPEaselStore.shared flush]; [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    NSCAssert(content.grid.subviews.count==0,@"another profile cannot see the first profile’s Easel cards");
    controller.context=@"Profile 1"; DPLibraryReloadCustomSection(controller);
    [DPEaselStore.shared flush]; [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    NSCAssert(content.grid.subviews.count==1,@"returning to the same profile restores its existing board");
    DPEaselCard *card=(id)content.grid.subviews.firstObject;
    NSCAssert(content.wantsLayer,@"custom section owns a complete backing surface for swipe translation");
    card.hovered=YES; NSCAssert(card.layer.backgroundColor!=nil,@"hover highlight has its own backing layer");
    card.hovered=NO; NSCAssert(card.layer.backgroundColor==nil,@"hover exit clears the backing highlight instead of retaining painted pixels");
    for(DPEaselCard *item in content.grid.subviews) item.hovered=YES;
    [card mouseEntered:nil];
    for(DPEaselCard *item in content.grid.subviews) NSCAssert(!item.hovered,@"enter reconciliation clears stale sibling hovers when the pointer is outside the inactive fixture window");
    controller.previousResponder=NSView.new; [content openCard:card];
    NSCAssert(!controller.previousResponder,@"opening another Easel cannot restore focus to the previously active tab when Library closes");
    DPEaselFixtureDelayDust=YES;
    content.undo.groupsByEvent=NO; [content.undo beginUndoGrouping]; [content deleteCard:card]; [content.undo endUndoGrouping];
    NSCAssert(content.removing && !document.deleted && content.grid.subviews.count==1,@"Easel card retains its grid slot until dust completes");
    DPEaselFixtureFinishDust(); DPEaselFixtureFinishDust=nil; DPEaselFixtureDelayDust=NO;
    waitUntil(^BOOL { return content.records.count==0; });
    NSCAssert(document.deleted,@"card deletion uses recoverable document trash");
    [content.undo undo]; waitUntil(^BOOL { return content.records.count==1; });
    NSCAssert(!document.deleted,@"Library undo restores the board");
    [content.undo redo]; waitUntil(^BOOL { return content.records.count==0; });
    NSCAssert(document.deleted,@"Library redo repeats deletion");
    [content toggleTrash:nil]; waitUntil(^BOOL { return content.records.count==1; }); [content layoutSubtreeIfNeeded];
    DPEaselCard *deletedCard=(id)content.grid.subviews.firstObject;
    NSEvent *contextEvent=[NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
    NSCAssert(deletedCard.trashed && !deletedCard.restoreButton.hidden && [deletedCard menuForEvent:contextEvent].numberOfItems==1,@"Recently Deleted exposes an explicit Restore action instead of deleting again");
    [content.undo beginUndoGrouping]; [content restoreCard:deletedCard]; [content.undo endUndoGrouping];
    waitUntil(^BOOL { return content.records.count==0; }); NSCAssert(!document.deleted,@"Recently Deleted restores the actual stored board");
    [content toggleTrash:nil]; waitUntil(^BOOL { return content.records.count==1; });
    DPEasels.on=NO; DPLibraryBuildCategories(controller); DPLibraryReloadCustomSection(controller);
    NSCAssert(controller.rail.subviews.count==3 && !controller.customContent,@"disable restores original rail and releases custom content");
    [DPEaselStore.shared flush]; [window close]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: optional rail registration, empty/create/search states, real local catalog, recoverable card delete/undo/redo and disable cleanup");
} }
