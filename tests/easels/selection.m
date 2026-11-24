#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
NSString *DPAppSupport(NSString *path) { return NSTemporaryDirectory(); }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,900,1400)];
    canvas.document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)];
    NSDictionary *shape=@{@"id":NSUUID.UUID.UUIDString,@"type":@"rectangle",@"z":@1,@"rect":@[@100,@200,@100,@80]};
    canvas.initialObjects=@[shape]; [canvas.selection addObject:shape[@"id"]]; canvas.origin=NSZeroPoint;
    for(NSNumber *value in @[@.5,@1,@2]) {
        CGFloat scale=value.doubleValue; [canvas setFrameSize:NSMakeSize(900*scale,1400*scale)]; [canvas setBoundsSize:NSMakeSize(900,1400)];
        NSCAssert(fabs(DPEaselScreenUnit(canvas)*scale-1)<.001,@"selection chrome uses stable screen points at every slide scale");
        canvas.resizing=-1; canvas.guides=nil;
        [canvas updateSelectionDrag:NSMakePoint(3.5/scale-100,50) modifiers:0];
        NSCAssert(fabs(NSMinX(DPEaselObjectRect(canvas.previewObjects[0])))<.001,@"four screen-point engagement independent of slide scale");
        [canvas updateSelectionDrag:NSMakePoint(6/scale-100,50) modifiers:0];
        NSCAssert(fabs(NSMinX(DPEaselObjectRect(canvas.previewObjects[0])))<.001,@"seven screen-point release remains stable");
        [canvas updateSelectionDrag:NSMakePoint(8/scale-100,50) modifiers:0];
        NSCAssert(fabs(NSMinX(DPEaselObjectRect(canvas.previewObjects[0]))-8/scale)<.001,@"release respects raw pointer without accumulated snap delta");
        canvas.resizing=0;
        NSRect stopped=DPEaselObjectRect([canvas resizeObject:shape toPoint:NSMakePoint(400,400) modifiers:NSEventModifierFlagOption neighbors:@[]]);
        NSCAssert(NSMaxX(stopped)==200 && NSMaxY(stopped)==280 && stopped.size.width==4 && stopped.size.height==4,@"resize crossing anchor stops without flipping or moving the opposite corner");
        canvas.resizing=2;
        NSRect snapped=DPEaselObjectRect([canvas resizeObject:shape toPoint:NSMakePoint(900-3/scale,350) modifiers:0 neighbors:@[]]);
        NSCAssert(NSMaxX(snapped)==900 && canvas.guides.count>0,@"resize aligns dragged edge to the canvas boundary");
    }
    NSDictionary *arrow=@{@"id":NSUUID.UUID.UUIDString,@"type":@"arrow",@"order":@2,@"z":@2,@"rect":@[@100,@100,@200,@200],@"points":@[@[@100,@100],@[@300,@300]]};
    NSCAssert(DPEaselSelectionHandles(arrow).count==2,@"arrow has its two actual endpoint handles");
    [canvas.document replaceObjects:@[arrow] action:@"Fixture"];
    [canvas.selection setSet:[NSSet setWithObject:arrow[@"id"]]];
    NSEvent *down=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:[canvas convertPoint:NSMakePoint(300,300) toView:nil]
        modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:1];
    [canvas mouseDown:down]; NSCAssert(canvas.resizing==1,@"pointer picks the arrow terminal handle rather than a bounding-box corner");
    canvas.resizing=1;
    NSDictionary *changed=[canvas resizeObject:arrow toPoint:NSMakePoint(40,170) modifiers:NSEventModifierFlagOption neighbors:@[]];
    NSCAssert(([changed[@"points"] isEqual:@[@[@100,@100],@[@40,@170]]]),@"arrow end crosses either axis while start stays fixed");
    canvas.resizing=0;
    changed=[canvas resizeObject:arrow toPoint:NSMakePoint(220,300) modifiers:NSEventModifierFlagShift neighbors:@[]];
    NSCAssert(([changed[@"points"] isEqual:@[@[@220,@300],@[@300,@300]]]),@"Shift arrow-start edit keeps direction and fixed terminal endpoint");
    puts("PASS: screen-constant selection/snapping, resize guides, nonflipping minimum and independent directed arrow endpoints");
} }
