#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static NSEvent *mouse(DPEaselCanvas *canvas,NSEventType type,NSArray *point) {
    NSPoint p=NSMakePoint([point[0] doubleValue],[point[1] doubleValue]);
    return [NSEvent mouseEventWithType:type location:[canvas convertPoint:p toView:nil] modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:0 context:nil eventNumber:1 clickCount:1 pressure:1];
}
static void runFor(NSTimeInterval duration) {
    NSDate *until=[NSDate dateWithTimeIntervalSinceNow:duration];
    while(until.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
}
static void stroke(DPEaselCanvas *canvas,NSArray *points) {
    [canvas selectTool:@"pen"]; [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,points.firstObject)];
    for(NSArray *p in [points subarrayWithRange:NSMakeRange(1,points.count-1)]) [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,p)];
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; document.undo.groupsByEvent=NO;
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,900,1400)]; canvas.document=document;
    for(NSString *type in @[@"line",@"rectangle",@"oval",@"heart",@"triangle",@"diamond",@"star"]) {
        NSArray *points=DPEaselTemplate(type,NSMakeRect(150,250,180,140)); stroke(canvas,points);
        runFor(.6); NSCAssert([canvas.draft[@"type"] isEqual:@"pen"],@"ordinary short pause must not refine %@",type);
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:2];
        while([canvas.draft[@"type"] isEqual:@"pen"] && deadline.timeIntervalSinceNow>0) runFor(.02);
        NSCAssert([canvas.draft[@"type"] isEqual:type],@"actual dwell timer refines %@",type);
        NSCAssert(document.objects.count==1,@"dwell preview never persists an unfinished stroke");
        [document.undo beginUndoGrouping]; [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,points.lastObject)]; [document.undo endUndoGrouping];
        NSCAssert(document.objects.count==2 && [document.objects.lastObject[@"type"] isEqual:type],@"release commits refined %@ once",type);
        [document.undo undo]; NSCAssert(document.objects.count==1,@"one undo removes the entire refined shape");
    }
    NSArray *oval=DPEaselTemplate(@"oval",NSMakeRect(100,300,150,100)); stroke(canvas,oval); runFor(1.35);
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,@[@290,@460])];
    NSCAssert([canvas.draft[@"type"] isEqual:@"pen"] && canvas.samples.count>oval.count,@"moving after dwell resumes the original raw stroke");
    [canvas selectTool:@"select"]; runFor(1.35);
    NSCAssert(!canvas.draft && !canvas.dwell && !canvas.refinementClock && document.objects.count==1,@"cancelled dwell cannot reappear or keep a timer alive");
    [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: real dwell timing, short-pause rejection, four shape commits/undo, resumed raw stroke and cancelled timer cleanup");
} }
