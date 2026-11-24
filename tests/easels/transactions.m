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
    NSDictionary *a=@{@"id":@"a",@"x":@10},*b=@{@"id":@"b",@"x":@20},*c=@{@"id":@"c",@"x":@30};
    NSDictionary *movedA=@{@"id":@"a",@"x":@15},*movedB=@{@"id":@"b",@"x":@25};
    BOOL conflict=NO;
    NSArray *merged=DPEaselMergeGesture(@[a,b],@[movedA,b],@[a,movedB,c],&conflict);
    NSCAssert((!conflict && [merged isEqual:@[movedA,movedB,c]]),@"local move preserves another window's different move and newly imported image");
    merged=DPEaselMergeGesture(@[a,b],@[a,b,c],@[b],&conflict);
    NSCAssert((!conflict && [merged isEqual:@[b,c]]),@"drawing from an older snapshot does not resurrect another window's deleted object");
    merged=DPEaselMergeGesture(@[a,b],@[movedA,movedB],@[b],&conflict);
    NSCAssert(conflict && [merged isEqual:@[b]],@"conflicting group move cancels atomically instead of resurrecting or partially moving objects");
    merged=DPEaselMergeGesture(@[a,b],@[movedA,b],@[@{@"id":@"a",@"x":@50},b],&conflict);
    NSCAssert(conflict && [merged[0][@"x"] isEqual:@50],@"older gesture cannot overwrite a newer edit to the same object");
    merged=DPEaselMergeGesture(@[a,b],@[movedA,b],@[movedA,b,c],&conflict);
    NSCAssert((!conflict && [merged isEqual:@[movedA,b,c]]),@"identical concurrent outcome retains newer additions without reporting a conflict");
    NSDictionary *local=@{@"id":@"local",@"order":@2,@"z":@2},*remote=@{@"id":@"remote",@"order":@2,@"z":@2};
    merged=DPEaselMergeGesture(@[a,b],@[a,b,local],@[a,b,remote],&conflict);
    NSCAssert(!conflict && [merged.lastObject[@"order"] isEqual:@3] && [merged.lastObject[@"z"] isEqual:@3] && merged[2]==remote,@"simultaneous new marks receive distinct creation/layer order without changing the other window's published object");
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; document.undo.groupsByEvent=NO;
    NSDictionary *rectangle=@{@"id":NSUUID.UUID.UUIDString,@"type":@"rectangle",@"order":@1,@"z":@1,@"rect":@[@100,@200,@100,@80]};
    NSDictionary *oval=@{@"id":NSUUID.UUID.UUIDString,@"type":@"oval",@"order":@2,@"z":@2,@"rect":@[@500,@600,@100,@80]};
    [document.undo beginUndoGrouping]; [document replaceObjects:[document.objects arrayByAddingObject:rectangle] action:@"Fixture"]; [document.undo endUndoGrouping];
    DPEaselCanvas *left=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,900,1400)]; left.document=document;
    DPEaselCanvas *right=[[DPEaselCanvas alloc] initWithFrame:left.frame]; right.document=document;
    left.initialObjects=document.objects; left.origin=NSZeroPoint; [left.selection addObject:rectangle[@"id"]];
    [left updateSelectionDrag:NSMakePoint(20,0) modifiers:NSEventModifierFlagOption];
    [document.undo beginUndoGrouping]; [right commit:[document.objects arrayByAddingObject:oval] action:@"Other window add"]; [document.undo endUndoGrouping];
    [document.undo beginUndoGrouping]; [left commit:left.previewObjects action:@"Move"]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.count==3 && DPEaselObjectRect(document.objects[1]).origin.x==120 && [document.objects.lastObject isEqual:oval],@"actual two-canvas commit preserves another placement's new object during a drag");
    [document.undo undo];
    NSCAssert(document.objects.count==3 && DPEaselObjectRect(document.objects[1]).origin.x==100,@"one undo reverses the local gesture and retains the other placement's addition");
    [left cancelGesture]; left.initialObjects=document.objects; left.origin=NSZeroPoint;
    [left updateSelectionDrag:NSMakePoint(30,0) modifiers:NSEventModifierFlagOption];
    [right.selection addObject:rectangle[@"id"]];
    [document.undo beginUndoGrouping]; [right delete:nil]; [document.undo endUndoGrouping];
    [document.undo beginUndoGrouping]; [left commit:left.previewObjects action:@"Stale move"]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.count==2 && [document.objects.lastObject isEqual:oval],@"actual stale commit cannot resurrect an object deleted by another placement");
    [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: concurrent gesture merge preserves independent edits/imports/deletes and rejects conflicting stale group changes");
} }
