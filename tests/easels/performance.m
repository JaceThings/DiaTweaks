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
    DPEaselDocument *doc=[DPEaselDocument documentWithSize:NSMakeSize(1000,1400)];
    NSMutableArray *objects=NSMutableArray.new;
    for(NSUInteger i=0;i<200;i++) {
        NSRect frame=NSMakeRect(20+(i%10)*90,20+(i/10)*55,82,45);
        NSDictionary *object=i%3==0 ? DPEaselText([NSString stringWithFormat:@"Note %lu",(unsigned long)i],frame,i,NO) :
            @{@"id":NSUUID.UUID.UUIDString,@"type":i%3==1 ? @"rectangle" : @"oval",@"order":@(i),@"z":@(i),@"rect":DPEaselRectArray(frame),@"color":@[@.4,@.7,@.9,@1]};
        [objects addObject:object];
    }
    [doc.undo disableUndoRegistration]; [doc replaceObjects:objects action:@"Stress fixture"]; [doc.undo enableUndoRegistration];
    DPEaselEditorSurface *surface=(id)DPEaselEditor(doc);
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1000,700) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO; window.contentView=surface; [surface layoutSubtreeIfNeeded];
    NSRect viewport=NSMakeRect(0,0,1000,650); NSMutableArray *times=NSMutableArray.new;
    NSBitmapImageRep *pixels=[surface.canvas bitmapImageRepForCachingDisplayInRect:viewport];
    for(NSUInteger i=0;i<90;i++) { @autoreleasepool {
        NSMutableArray *preview=[objects mutableCopy]; preview[0]=DPEaselTransformObject(objects[0],NSMakeRect(20+i,20,82,45)); surface.canvas.previewObjects=preview;
        CFAbsoluteTime start=CFAbsoluteTimeGetCurrent(); [surface.canvas cacheDisplayInRect:viewport toBitmapImageRep:pixels];
        [times addObject:@((CFAbsoluteTimeGetCurrent()-start)*1000)];
    } }
    [times sortUsingSelector:@selector(compare:)];
    printf("200-object native viewport: median %.2f ms, p95 %.2f ms, max %.2f ms (offscreen CPU render, not display pacing)\n",[times[45] doubleValue],[times[85] doubleValue],[times.lastObject doubleValue]);
    NSCAssert([times[85] doubleValue]<40,@"200-object render remains interactive in unoptimized fixture");
    [surface removeFromSuperview]; [window close];
    puts("PASS: 200 mixed objects render while moving one; no full-model save during pointer preview");
} }
