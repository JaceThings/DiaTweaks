#import "Patches/Easels/HostInternal.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.controlAccentColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
@interface EaselFixtureNavigation : NSObject
@property NSMutableArray *observers;
- (void)addObserver:(id)observer;
- (void)removeObserver:(id)observer;
@end
@implementation EaselFixtureNavigation
- (void)addObserver:(id)observer { if(!_observers) _observers=NSMutableArray.new; [_observers addObject:observer]; }
- (void)removeObserver:(id)observer { [_observers removeObjectIdenticalTo:observer]; }
@end
@interface EaselFixtureContents : NSObject
@property NSURL *url;
@property EaselFixtureNavigation *navigationController;
@end
@implementation EaselFixtureContents @end
@interface StoredEaselTab : NSObject
@property NSURL *URL;
@property NSUInteger closed;
- (void)close:(id)sender;
@end
@implementation StoredEaselTab
- (void)close:(id)sender { self.closed++; }
@end
@interface StoredEaselWindow : NSObject
@property NSArray *appleScriptTabs;
@end
@implementation StoredEaselWindow @end
@interface StoredEaselApplication : NSObject <NSApplicationDelegate>
@property NSArray *appleScriptWindows;
@end
@implementation StoredEaselApplication @end
static void settle(DPEaselStore *store) {
    [store flush];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.03]];
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    __weak DPEaselDocument *released=nil;
    @autoreleasepool {
        DPEaselDocument *ephemeral=[DPEaselDocument documentWithSize:NSMakeSize(500,600)]; ephemeral.undo.groupsByEvent=NO;
        released=ephemeral; [ephemeral.undo beginUndoGrouping]; [ephemeral replaceObjects:@[] action:@"Delete"]; [ephemeral.undo endUndoGrouping];
    }
    NSCAssert(!released,@"closed documents do not retain themselves through undo history");
    DPEaselStore *store=DPEaselStore.shared;
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)];
    NSCAssert([document.profile isEqual:@"Profile 1"],@"legacy unowned boards remain in the original profile");
    document.profile=@"Profile 6";
    NSCAssert([[[DPEaselDocument alloc] initWithSnapshot:document.snapshot].profile isEqual:@"Profile 6"],@"profile ownership persists in board snapshots");
    NSCAssert(document && [document.title isEqual:@"Untitled"],@"new heading is a real placeholder object");
    NSMutableDictionary *legacy=[document.snapshot mutableCopy]; [legacy removeObjectForKey:@"titleModel"];
    NSMutableDictionary *oldHeading=[legacy[@"objects"][0] mutableCopy]; [oldHeading removeObjectForKey:@"isTitle"]; oldHeading[@"text"]=@"Untitled Easel"; legacy[@"objects"]=@[oldHeading];
    DPEaselDocument *migrated=[[DPEaselDocument alloc] initWithSnapshot:legacy];
    NSCAssert([migrated.title isEqual:@"Untitled"] && [migrated.objects[0][@"text"] isEqual:@"Untitled"] && [migrated.objects[0][@"isTitle"] boolValue],@"old untouched placeholder migrates to dedicated Untitled heading");
    document.undo.groupsByEvent=NO;
    NSDictionary *first=DPEaselText(@"\n  First   board\nsubtitle",NSMakeRect(10,10,300,60),1,NO);
    NSDictionary *second=DPEaselText(@"Second",NSMakeRect(20,20,300,60),2,NO);
    [document.undo beginUndoGrouping];
    [document replaceObjects:@[second,document.objects[0],first] action:@"Type"];
    [document.undo endUndoGrouping];
    NSCAssert([document.title isEqual:@"Untitled"],@"body text never becomes the board title");
    NSMutableDictionary *heading=[document.objects[1] mutableCopy]; heading[@"text"]=@"\n  First   board\nsubtitle"; heading[@"placeholder"]=@NO;
    [document.undo beginUndoGrouping]; [document replaceObjects:@[second,heading,first] action:@"Edit Heading"]; [document.undo endUndoGrouping];
    NSCAssert([document.title isEqual:@"First board"],@"designated heading supplies first meaningful line, normalized");
    [document.undo beginUndoGrouping]; [document replaceObjects:@[second,first] action:@"Delete Heading"]; [document.undo endUndoGrouping];
    NSCAssert([document.title isEqual:@"Untitled"],@"deleted heading defaults to Untitled without promoting body text");
    [document.undo undo]; NSCAssert([document.title isEqual:@"First board"],@"undo restores designated heading and name");
    [document.undo redo]; NSCAssert([document.title isEqual:@"Untitled"],@"redo keeps body text out of title");
    [document.undo beginUndoGrouping]; [document rename:@"Renamed board"]; [document.undo endUndoGrouping];
    NSCAssert([document.title isEqual:@"Renamed board"] && [document.objects.lastObject[@"isTitle"] boolValue],@"rename recreates a deleted heading");
    __block NSError *failure=nil;
    [store save:document completion:^(NSError *error){ failure=error; }]; settle(store);
    NSCAssert(!failure && [[NSFileManager defaultManager] fileExistsAtPath:[store pageURL:document.identifier].path],@"atomic document plus fallback page saved");
    NSCAssert([[store identifierForURL:[store pageURL:document.identifier]] isEqual:document.identifier],@"exact durable file URL resolves");
    NSCAssert(![store identifierForURL:[NSURL URLWithString:@"https://example.com/index.html"]] && ![store directory:@"../escape"],@"external and traversal identities rejected");
    DPEaselStore *reopened=[[DPEaselStore alloc] initWithRoot:[NSURL fileURLWithPath:root]];
    NSCAssert([[[reopened load:document.identifier error:nil] title] isEqual:@"Renamed board"],@"independent registry restores persisted content");
    [store save:document completion:nil]; settle(store);
    NSURL *manifest=[[store directory:document.identifier] URLByAppendingPathComponent:@"document.json"];
    [@"truncated" writeToURL:manifest atomically:YES encoding:NSUTF8StringEncoding error:nil];
    DPEaselStore *recovery=[[DPEaselStore alloc] initWithRoot:[NSURL fileURLWithPath:root]];
    NSCAssert([recovery load:document.identifier error:nil],@"malformed current manifest recovers last known good revision");
    NSMutableDictionary *bad=[document.snapshot mutableCopy]; bad[@"size"]=@[@(NAN),@1400];
    NSCAssert(!DPEaselValidSnapshot(bad),@"nonfinite canvas rejected");
    bad=[document.snapshot mutableCopy]; bad[@"objects"]=@[second,second];
    NSCAssert(!DPEaselValidSnapshot(bad),@"duplicate object IDs rejected");
    NSMutableDictionary *invisible=[second mutableCopy]; invisible[@"type"]=@"arrow";
    bad=[document.snapshot mutableCopy]; bad[@"objects"]=@[invisible];
    NSCAssert(!DPEaselValidSnapshot(bad),@"an arrow without its directed endpoints is rejected instead of becoming an invisible object");
    [store save:document completion:nil]; settle(store);
    [DPEaselHost install];
    NSMutableArray *longObjects=[document.objects mutableCopy];
    NSMutableDictionary *longHeading=[longObjects.lastObject mutableCopy]; longHeading[@"text"]=@"A long heading that grows during the initial native editor mount";
    longObjects[longObjects.count-1]=longHeading;
    [document.undo beginUndoGrouping]; [document replaceObjects:longObjects action:@"Test Long Heading"]; [document.undo endUndoGrouping];
    EaselFixtureContents *contents=EaselFixtureContents.new; contents.url=[store pageURL:document.identifier];
    contents.navigationController=EaselFixtureNavigation.new;
    DPEaselAttachment *attachment=DPEaselAttachmentFor(contents,YES);
    NSView *pane=[[NSView alloc] initWithFrame:NSMakeRect(0,0,700,600)]; attachment.pane=pane;
    [attachment refresh]; NSCAssert(attachment.editor.superview==pane,@"editor attaches only inside owning pane");
    NSCAssert(pane.subviews.count==1,@"heading fit notifications cannot reenter mounting and leave duplicate editors");
    ((void (*)(id,SEL,id,id))objc_msgSend)(attachment,@selector(webContents:didStartProvisionalNavigation:),contents,nil);
    [attachment refresh]; NSCAssert(!attachment.editor.superview,@"layout/theme refresh cannot remount the previous Easel while navigation is pending");
    contents.url=[NSURL URLWithString:@"https://example.com/"];
    ((void (*)(id,SEL,id,id))objc_msgSend)(attachment,@selector(webContents:didCommitNavigation:),contents,nil);
    NSCAssert(!attachment.editor && !pane.subviews.count,@"navigation away cleans native editor without hiding page content");
    contents.url=[store pageURL:document.identifier]; [attachment refresh];
    NSCAssert(attachment.editor,@"back navigation recovers board");
    EaselFixtureContents *webpage=EaselFixtureContents.new; webpage.url=[NSURL URLWithString:@"https://example.com/"]; webpage.navigationController=EaselFixtureNavigation.new;
    DPEaselBindPane(webpage,pane);
    NSCAssert(!attachment.pane && !attachment.editor && !pane.subviews.count,@"a reused pane drops the old tab overlay even without native detach");
    DPEaselBindPane(contents,pane);
    NSCAssert(attachment.editor.superview==pane && !DPEaselAttachmentFor(webpage,NO).pane,@"returning to Easel reclaims exclusive pane ownership");
    DPEasels.on=NO; [DPEaselHost refresh]; NSCAssert(!pane.subviews.count,@"toggle off removes owned surfaces");
    NSCAssert(!contents.navigationController.observers.count,@"disabled feature removes its navigation observers");
    DPEasels.on=YES; [DPEaselHost refresh]; NSCAssert(pane.subviews.count==1,@"toggle on mounts exactly once");
    StoredEaselTab *placement=StoredEaselTab.new,*another=StoredEaselTab.new,*ordinary=StoredEaselTab.new;
    placement.URL=another.URL=[store pageURL:document.identifier]; ordinary.URL=[NSURL URLWithString:@"https://example.com/"];
    StoredEaselWindow *facade=StoredEaselWindow.new; facade.appleScriptTabs=@[placement,another,ordinary];
    StoredEaselApplication *application=StoredEaselApplication.new; application.appleScriptWindows=@[facade];
    id oldDelegate=NSApp.delegate; NSApp.delegate=application;
    DPEaselTrashDocument(document,^(NSError *error){ failure=error; }); settle(store); [attachment refresh]; NSApp.delegate=oldDelegate;
    NSCAssert(placement.closed==1 && another.closed==1 && ordinary.closed==0,@"stored-board deletion closes all matching placements and no ordinary tabs");
    NSCAssert(!failure && document.deleted && !attachment.editor,@"deleted document unmounts and moves to recoverable trash");
    [store save:document completion:^(NSError *error){ failure=error; }];
    NSCAssert(failure && ![NSFileManager.defaultManager fileExistsAtPath:manifest.path],@"late save cannot resurrect deleted board");
    [store restore:document completion:^(NSError *error){ failure=error; }]; settle(store); [attachment refresh];
    NSCAssert(!failure && !document.deleted && attachment.editor,@"restored document is editable again");
    NSURL *coldRoot=[[NSURL fileURLWithPath:root] URLByAppendingPathComponent:@"ColdStart"];
    DPEaselStore *writer=[[DPEaselStore alloc] initWithRoot:coldRoot]; DPEaselDocument *saved=[DPEaselDocument documentWithSize:NSMakeSize(600,900)];
    [writer save:saved completion:nil]; settle(writer); [writer trash:saved completion:nil]; settle(writer);
    DPEaselStore *cold=[[DPEaselStore alloc] initWithRoot:coldRoot];
    DPEaselDocument *deleted=[cold loadTrashed:saved.identifier error:nil];
    NSCAssert(deleted.deleted && [deleted.objects isEqual:saved.objects] && ![cold load:saved.identifier error:nil],@"cold-start recovery opens Trash without pretending the board is live");
    __block NSArray *trashRecords=nil; [cold listTrashed:^(NSArray *records,NSError *error){ trashRecords=records; }]; settle(cold);
    NSCAssert(trashRecords.count==1,@"Recently Deleted is listed from durable summaries after a fresh registry");
    [cold restore:deleted completion:^(NSError *error){ failure=error; }]; settle(cold);
    NSCAssert(!failure && !deleted.deleted && [[[DPEaselStore alloc] initWithRoot:coldRoot] load:deleted.identifier error:nil],@"cold-start Restore returns the complete board to normal storage");
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: naming/undo, schema rejection, atomic restore/recovery, strict URLs, pane navigation/toggle, recoverable deletion and stale-save rejection");
} }
