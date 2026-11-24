#import "Patches/Tasks/TaskView.h"
#import <stdio.h>
@interface TaskHoverWindow : NSWindow
@property NSPoint fixturePointer;
@property BOOL fixtureKey;
@end
@implementation TaskHoverWindow
- (BOOL)isKeyWindow { return self.fixtureKey; }
- (NSPoint)mouseLocationOutsideOfEventStream { return self.fixturePointer; }
@end
@interface FixtureTaskOwner : NSObject
@property NSView *customContent;
@property BOOL expanded,closing;
@end
@implementation FixtureTaskOwner @end
DPPatch DPSidebarLibraryDust={.on=YES};
static NSString *root;
static NSUInteger dissolves;
static BOOL deferDust;
static void (^finishDust)(void);
DPPatch DPTasks={.on=YES};
NSString *DPAppSupport(NSString *path) { return [path isEqual:@"DiaPatches/Tasks"] ? root : [root stringByAppendingPathComponent:path]; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
NSButton *DPLibraryMakeButton(NSString *title,NSString *symbol,id target,SEL action) {
    return [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] target:target action:action];
}
void DPLibraryDissolve(NSArray<NSView *> *views,void (^completion)(void)) { dissolves++; for(NSView *view in views) view.alphaValue=0; if(deferDust) finishDust=[completion copy]; else completion(); }
NSPopUpButton *DPLibraryMakeFilterButton(id target,SEL action) { NSPopUpButton *button=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO]; button.target=target; button.action=action; return button; }
static void waitFor(BOOL (^done)(void)) {
    NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:3];
    while(!done() && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(done(),@"asynchronous operation completes");
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPTaskStore *store=DPTaskStore.shared; waitFor(^BOOL{ return store.loaded; });
    DPTaskStore *other=[DPTaskStore storeForProfile:@"Profile 6"]; waitFor(^BOOL{ return other.loaded; });
    NSCAssert(store==[DPTaskStore storeForProfile:@"Profile 1"] && other==[DPTaskStore storeForProfile:@"Profile 6"] && store!=other,@"spaces sharing a profile resolve one store; different profiles resolve different stores");
    NSCAssert([other add:@"Other profile task"] && !store.items.count,@"another profile cannot populate the first profile’s task list");
    [other flush];
    NSCAssert(![DPTaskStore storeForProfile:@"../escape"],@"profile names cannot escape the task root");
    NSCAssert(!store.error && ![store add:@"  "],@"empty input is ignored");
    NSCAssert([store add:@"First task — नमस्ते"] && [store add:@"Second task"],@"Unicode tasks save locally");
    NSString *identifier=store.items.lastObject[@"id"];
    [store setCompleted:YES identifier:identifier]; [store flush];
    DPTaskStore *restored=[[DPTaskStore alloc] initWithRoot:[NSURL fileURLWithPath:root]]; waitFor(^BOOL{ return restored.loaded; });
    NSCAssert(restored.items.count==2 && [restored.items.lastObject[@"completed"] boolValue],@"restart preserves task text and completion");
    DPTaskContent *content=[[DPTaskContent alloc] initWithFrame:NSMakeRect(0,0,414,650)];
    TaskHoverWindow *window=[[TaskHoverWindow alloc] initWithContentRect:content.bounds styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO; window.contentView=content;
    FixtureTaskOwner *owner=FixtureTaskOwner.new; owner.customContent=content; owner.expanded=YES; content.library=(id)owner;
    [content reload];
    NSCAssert(!content.wantsInitialFocus && window.firstResponder!=nil,@"opening the ready Tasks section focuses its input once");
    [content layoutSubtreeIfNeeded];
    NSCAssert(content.filter==1 && content.records.count==1,@"incomplete is default and completed items remain stored");
    DPTaskCell *cell=(id)[content.table viewAtColumn:0 row:0 makeIfNecessary:YES];
    NSCAssert(cell.textField && [cell.textField.stringValue isEqual:@"Second task"] && cell.textField.superview==cell,@"the real table cell retains and displays its task label");
    NSPoint labelPoint=[cell convertPoint:NSMakePoint(80,25) toView:nil];
    NSEvent *click=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:labelPoint modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
    [content.table mouseDown:click]; NSCAssert(cell.editing && cell.textField.editable,@"native table forwards a single row click into inline editing");
    NSCAssert(![(NSTextView *)cell.textField.currentEditor drawsBackground] && cell.textField.currentEditor.selectedRange.length==0,@"inline editor is transparent and starts with a caret, not a selection box");
    NSMenu *rowMenu=[content.table menuForEvent:click]; NSCAssert(rowMenu.itemArray.count==2 && [rowMenu.itemArray[0].title isEqual:@"Edit"] && [rowMenu.itemArray[1].title isEqual:@"Delete"],@"right click has task-specific Edit and Delete actions");
    cell.textField.stringValue=@"Second task"; [cell commitEditing:nil];
    cell=(id)[content.table viewAtColumn:0 row:0 makeIfNecessary:YES];
    [content toggleTask:cell.check];
    NSCAssert(content.records.count==1 && [store.items.firstObject[@"completed"] boolValue],@"completion persists immediately while the checked row briefly remains");
    waitFor(^BOOL{ return content.records.count==0; });
    NSCAssert(cell.alphaValue==1,@"dust snapshots never leave a reusable task cell hidden");
    content.filter=2; [content reload]; NSCAssert(content.records.count==2,@"completed filter keeps recoverable checked items");
    cell=(id)[content.table viewAtColumn:0 row:0 makeIfNecessary:YES]; [content toggleTask:cell.check];
    NSCAssert(content.records.count==1 && ![store.items.firstObject[@"completed"] boolValue],@"unchecking restores an incomplete task");
    content.filter=0; content.query=@"नमस्ते"; [content reload]; NSCAssert(content.records.count==1,@"search includes Unicode task names");
    content.query=@""; content.input.stringValue=@"Added with Return"; [content.input sendAction:content.input.action to:content.input.target];
    NSCAssert(store.items.count==3 && !content.input.stringValue.length,@"native input action adds above and clears input");
    [content clearTasks:nil]; NSCAssert(!store.items.count && store.cleared.count==3,@"clear is immediately recoverable");
    NSCAssert(content.table.alphaValue==1,@"clearing restores the table immediately for newly added tasks");
    [content restoreTasks:nil]; NSCAssert(store.items.count==3 && !store.cleared.count,@"restore recovers all task states");
    for(NSAppearanceName appearance in @[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]) {
        content.appearance=[NSAppearance appearanceNamed:appearance];
        for(NSNumber *width in @[@330,@414,@510]) {
            content.frame=NSMakeRect(0,0,width.doubleValue,650); [content layoutSubtreeIfNeeded];
            NSCAssert(NSWidth(content.table.frame)<=NSWidth(content.scroll.contentView.bounds)+.5 && content.table.intercellSpacing.width==0,@"task row right edge stays inside the viewport so rounded hover is not clipped");
            for(NSUInteger row=0;row<content.records.count;row++) {
                DPTaskCell *rowCell=(id)[content.table viewAtColumn:0 row:row makeIfNecessary:YES]; [rowCell layoutSubtreeIfNeeded];
                CALayer *highlight=rowCell.layer.sublayers.firstObject;
                NSRect inClip=[rowCell convertRect:highlight.frame toView:content.scroll.contentView];
                NSCAssert(NSMaxX(inClip)<=NSMaxX(content.scroll.contentView.bounds)-1 && NSWidth(highlight.frame)>NSWidth(rowCell.bounds)-20,@"actual hover right corner stays inside the clip viewport without unnecessarily narrowing the row");
                NSCAssert(highlight.cornerRadius==11 && NSMinX(highlight.frame)>=2,@"both hover corners retain their radius and inset");
            }
            NSBitmapImageRep *rep=[content bitmapImageRepForCachingDisplayInRect:content.bounds]; [content cacheDisplayInRect:content.bounds toBitmapImageRep:rep];
            NSCAssert(rep.pixelsWide>0 && NSMaxX(content.composer.frame)<=NSWidth(content.bounds),@"native task UI fits narrow/wide Library in light/dark");
        }
    }
    content.filter=0; [content reload]; [content.table layoutSubtreeIfNeeded]; window.fixtureKey=YES;
    NSArray *cells=@[[content.table viewAtColumn:0 row:0 makeIfNecessary:YES],[content.table viewAtColumn:0 row:1 makeIfNecessary:YES],[content.table viewAtColumn:0 row:2 makeIfNecessary:YES]];
    for(DPTaskCell *hovered in cells) {
        window.fixturePointer=[hovered convertPoint:NSMakePoint(80,25) toView:nil]; [hovered mouseEntered:click];
        for(DPTaskCell *candidate in cells) {
            CALayer *highlight=candidate.layer.sublayers.firstObject;
            NSCAssert((highlight.backgroundColor!=nil)==(candidate==hovered),@"moving between tasks clears every previous hover layer");
        }
    }
    window.fixturePointer=NSMakePoint(-100,-100); DPLibraryReconcileHover(content.table);
    for(DPTaskCell *candidate in cells) NSCAssert(!candidate.layer.sublayers.firstObject.backgroundColor,@"scroll/exit reconciliation removes all stale task hover backgrounds");
    window.fixturePointer=[cells[0] convertPoint:NSMakePoint(80,25) toView:nil]; DPLibraryReconcileHover(content.table); window.fixtureKey=NO;
    [NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidResignKeyNotification object:window];
    NSCAssert(![(DPTaskCell *)cells[0] layer].sublayers.firstObject.backgroundColor,@"window deactivation clears task hover without an exit event");
    NSString *editedID=store.items.firstObject[@"id"];
    [store edit:@"  Edited task — नमस्ते  " identifier:editedID];
    NSCAssert([store.items.firstObject[@"text"] isEqual:@"Edited task — नमस्ते"],@"inline edits trim and retain Unicode");
    [store remove:editedID]; content.filter=3; [content reload];
    NSCAssert(content.records.count==1 && [content.records[0][@"id"] isEqual:editedID],@"individual deletion is visible in Deleted filter");
    [store restore:editedID]; content.filter=0; [content reload];
    NSCAssert(store.items.count==3 && store.cleared.count==0,@"restore preserves original task identity");
    DPTaskCell *deleting=(id)[content.table viewAtColumn:0 row:0 makeIfNecessary:YES]; NSString *deletedID=deleting.record[@"id"];
    deferDust=YES; NSUInteger countBefore=store.items.count; [deleting deleteTask:nil];
    NSCAssert(content.removing && store.items.count==countBefore && content.records.count==countBefore,@"task slot remains occupied while dust is active");
    finishDust(); finishDust=nil; deferDust=NO;
    NSCAssert(!content.removing && store.items.count==countBefore-1,@"only completed dust commits task removal and reflow");
    [store restore:deletedID];
    [store setCompleted:YES identifier:editedID]; [store clearCompleted];
    NSCAssert(store.cleared.count>0 && [store.items indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger i,BOOL *stop){ return [item[@"completed"] boolValue]; }]==NSNotFound,@"clear completed preserves incomplete tasks");
    [store restoreCleared]; [store flush];
        content.allowed=NO; [content reload]; content.input.stringValue=@"Private"; [content addTask:nil];
    NSCAssert(!content.records.count && !content.input.enabled && store.items.count==3,@"private windows neither expose nor add shared tasks");
    [content removeFromSuperview]; [window close]; [store flush];
    NSURL *bad=[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"bad"] isDirectory:YES]; [NSFileManager.defaultManager createDirectoryAtURL:bad withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *invalid=[@"{broken" dataUsingEncoding:NSUTF8StringEncoding]; NSURL *file=[bad URLByAppendingPathComponent:@"tasks.json"]; [invalid writeToURL:file atomically:YES];
    DPTaskStore *broken=[[DPTaskStore alloc] initWithRoot:bad]; waitFor(^BOOL{ return broken.loaded; });
    NSCAssert(broken.error && ![broken add:@"Must not overwrite"] && [[NSData dataWithContentsOfURL:file] isEqual:invalid],@"corrupt data remains untouched and writes are blocked");
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: durable Unicode tasks/completion, delayed dismissal, filters/search, Enter, reversible clear, light/dark widths and private/corrupt-data isolation");
} }
