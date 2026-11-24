#import "Patches/Easels/Canvas.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static NSEvent *mouse(DPEaselCanvas *canvas,NSEventType type,NSPoint point,NSEventModifierFlags modifiers,NSInteger clicks) {
    return [NSEvent mouseEventWithType:type location:[canvas convertPoint:point toView:nil] modifierFlags:modifiers
        timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:canvas.window.windowNumber context:nil eventNumber:1 clickCount:clicks pressure:1];
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; document.undo.groupsByEvent=NO;
    DPEaselEditorSurface *surface=(id)DPEaselEditor(document);
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,900,700) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO; window.contentView=surface; [surface layoutSubtreeIfNeeded];
    DPEaselCanvas *canvas=surface.canvas;
    NSRect heading=DPEaselObjectRect(document.objects.firstObject);
    NSCAssert(NSMinY(heading)==32 && NSMidX(heading)==450 && [document.title isEqual:@"Untitled"],@"new heading is centered close to the top of the logical slide");
    NSMutableDictionary *longHeading=[document.objects.firstObject mutableCopy]; longHeading[@"text"]=@"A longer heading that needs several lines without clipping";
    NSRect fittedHeading=DPEaselObjectRect(DPEaselGrowTitle(longHeading));
    NSCAssert(fittedHeading.size.height>heading.size.height && fittedHeading.size.width==heading.size.width && fittedHeading.origin.y==32,@"long headings grow down without changing slide geometry or top padding");
    NSCAssert(surface.buttons.count==7 && !surface.scroll.allowsMagnification,@"seven native tools on bounded nonzooming canvas");
    [document.undo beginUndoGrouping]; [canvas selectTool:@"rectangle"];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(100,200),0,1)];
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(220,260),NSEventModifierFlagShift,1)];
    [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(220,260),NSEventModifierFlagShift,1)]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.count==2 && [canvas.tool isEqual:@"rectangle"],@"gesture creates one object and keeps the rectangle tool active");
    [document.undo beginUndoGrouping];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(400,400),0,1)];
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(470,460),0,1)];
    [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(470,460),0,1)]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.count==3 && [canvas.tool isEqual:@"rectangle"],@"a second shape can be drawn without reselecting the tool");
    [document.undo undo]; [canvas selectTool:@"select"]; [canvas.selection addObject:document.objects.lastObject[@"id"]];
    NSDictionary *shape=document.objects.lastObject;
    NSCAssert(DPEaselObjectRect(shape).size.width==120 && DPEaselObjectRect(shape).size.height==120,@"Shift draw preserves square");
    [document.undo beginUndoGrouping];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(160,260),0,1)];
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(190,280),0,1)];
    [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(190,280),0,1)]; [document.undo endUndoGrouping];
    NSCAssert(DPEaselObjectRect(document.objects.lastObject).origin.x==130,@"move tracks raw pointer delta");
    [document.undo undo]; NSCAssert(DPEaselObjectRect(document.objects.lastObject).origin.x==100,@"one undo reverses whole move");
    [document.undo beginUndoGrouping]; [canvas duplicate:nil]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.count==3 && canvas.selection.count==1,@"duplicate gets independent identity and selection");
    [document.undo beginUndoGrouping]; [canvas delete:nil]; [document.undo endUndoGrouping];
    NSCAssert(document.objects.count==2,@"delete selected object only");
    [document.undo beginUndoGrouping];
    [canvas beginText:document.objects[0]]; canvas.textEditor.string=@"Native board";
    [canvas textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:canvas.textEditor]];
    [canvas endText]; [document.undo endUndoGrouping];
    NSCAssert([document.title isEqual:@"Native board"],@"native text editing updates heading-derived title");
    [document.undo undo]; NSCAssert([document.title isEqual:@"Untitled"],@"one undo restores whole text session");
    NSCAssert(canvas.accessibilityChildren.count==document.objects.count,@"every canvas object is exposed to accessibility");
    NSCAssert(canvas.accessibilityChildren.firstObject==canvas.accessibilityChildren.firstObject,@"accessibility object identities survive successive native queries");
    canvas.initialObjects=document.objects; canvas.origin=NSZeroPoint; canvas.moving=YES;
    [canvas.selection setSet:[NSSet setWithObject:document.objects.lastObject[@"id"]]];
    [canvas updateSelectionDrag:NSMakePoint(290,0) modifiers:0];
    NSCAssert(DPEaselObjectRect(canvas.previewObjects.lastObject).origin.x==390,@"canvas center guide engages exactly");
    [canvas updateSelectionDrag:NSMakePoint(296,0) modifiers:0];
    NSCAssert(DPEaselObjectRect(canvas.previewObjects.lastObject).origin.x==390,@"guide remains stable within a gentle release radius");
    [canvas updateSelectionDrag:NSMakePoint(298,0) modifiers:0];
    NSCAssert(DPEaselObjectRect(canvas.previewObjects.lastObject).origin.x==398,@"guide releases after seven points without pulling back");
    [canvas cancelGesture];
    NSDictionary *stroke=@{@"id":NSUUID.UUID.UUIDString,@"type":@"pen",@"z":@0,@"rect":@[@100,@100,@200,@200],@"points":@[@[@100,@100],@[@300,@300]]};
    canvas.previewObjects=@[stroke];
    NSCAssert(![canvas objectAtPoint:NSMakePoint(105,295)] && [canvas objectAtPoint:NSMakePoint(200,200)],@"stroke hit testing follows actual ink instead of its empty bounding box");
    canvas.previewObjects=nil;
    NSSize original=canvas.bounds.size; NSSize oldDisplay=canvas.frame.size;
    [surface setFrameSize:NSMakeSize(500,600)]; [surface layoutSubtreeIfNeeded];
    NSCAssert(fabs(original.width-NSWidth(canvas.bounds))<.001 && fabs(original.height-NSHeight(canvas.bounds))<.001 && NSWidth(canvas.frame)<oldDisplay.width,@"window resizing scales slide without changing logical geometry");
    NSPoint canvasRight=[surface convertPoint:NSMakePoint(NSWidth(canvas.bounds),0) fromView:canvas];
    NSRect viewport=[surface convertRect:surface.scroll.contentView.bounds fromView:surface.scroll.contentView];
    NSCAssert(fabs(canvasRight.x-NSMaxX(viewport))<1,@"scaled canvas reaches the drawing viewport's right edge");
    NSCAssert(NSHeight(surface.colorWell.frame)==NSHeight(surface.toolbar.frame) && NSMinX(surface.colorWell.frame)>NSMaxX(surface.toolbar.frame),@"drawing color is a permanent matching square beside toolbar");
    [surface setFrameSize:NSMakeSize(270,720)]; [surface layoutSubtreeIfNeeded];
    NSRect narrowViewport = surface.scroll.contentView.bounds;
    NSRect drawArea = [canvas convertRect:canvas.bounds toView:surface.scroll.contentView];
    NSCAssert(NSWidth(drawArea) >= NSWidth(narrowViewport)-1 && NSHeight(drawArea) >= NSHeight(narrowViewport)-1,
        @"the drawable canvas reaches both edges in a tall split pane");
    NSPoint bottom = [canvas convertPoint:NSMakePoint(NSMidX(narrowViewport), NSMaxY(narrowViewport)-4) fromView:surface.scroll.contentView];
    NSCAssert(NSPointInRect(bottom,canvas.bounds), @"pointer coordinates near the bottom stay in the board after resizing");
    [surface setFrameSize:NSMakeSize(500,600)]; [surface layoutSubtreeIfNeeded];
    NSCAssert([canvas acceptsFirstMouse:nil],@"first click draws without a focus-only click");
    NSUInteger beforeFlat=document.objects.count;
    [canvas selectTool:@"rectangle"];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(300,500),0,1)];
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(400,500),0,1)];
    [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(400,500),0,1)];
    NSCAssert(document.objects.count==beforeFlat,@"flat shape drag does not leave an invisible rectangle");
    [document.undo beginUndoGrouping]; [canvas selectTool:@"rectangle"];
    [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(850,850),0,1)];
    [canvas mouseDragged:mouse(canvas,NSEventTypeLeftMouseDragged,NSMakePoint(895,900),0,1)];
    [canvas mouseUp:mouse(canvas,NSEventTypeLeftMouseUp,NSMakePoint(895,900),0,1)]; [document.undo endUndoGrouping];
    NSCAssert(NSMaxX(DPEaselObjectRect(document.objects.lastObject))==895,@"after resizing, the first gesture can draw beside the logical right edge");
    NSDictionary *image=@{@"id":NSUUID.UUID.UUIDString,@"type":@"image",@"asset":NSUUID.UUID.UUIDString,@"rect":@[@40,@400,@100,@80],@"order":@100,@"z":@100};
    [document.undo beginUndoGrouping]; [document replaceObjects:[document.objects arrayByAddingObject:image] action:@"Test image"]; [document.undo endUndoGrouping];
    [canvas.selection setSet:[NSSet setWithObject:image[@"id"]]]; [surface updateContextTools];
    NSCAssert(!surface.contextTools && !DPEaselObjectCanColor(image),@"image selection exposes no object color or font controls");
    NSCAssert(!surface.objectColorWell || surface.objectColorWell.hidden,@"images never show the attached color control");
    surface.paletteEditsSelection=YES; NSButton *swatch=NSButton.new; swatch.tag=3;
    [document.undo beginUndoGrouping]; [surface selectColor:swatch]; [document.undo endUndoGrouping];
    NSCAssert(([document.objects.lastObject isEqual:image] && [canvas.color isEqual:@[@.98,@.23,@.10,@1]]),@"permanent color changes future drawing ink without mutating selected images");
    [canvas selectTool:@"oval"]; swatch.tag=9; surface.paletteEditsSelection=NO; [surface selectColor:swatch];
    [canvas selectTool:@"rectangle"];
    NSCAssert(([canvas.color isEqual:@[@.98,@.23,@.10,@1]]),@"rectangle remembers its own last drawing color");
    [canvas selectTool:@"oval"];
    NSCAssert(([canvas.color isEqual:@[@0,@.72,@.88,@1]]),@"oval remembers its different drawing color across tool changes");
    [canvas.selection setSet:[NSSet setWithObject:document.objects.firstObject[@"id"]]];
    [surface updateContextTools]; NSView *stablePill=surface.contextTools;
    NSCAssert(surface.objectColorWell && !surface.objectColorWell.hidden && surface.colorWell.superview==surface,@"selected text has an attached color control alongside the permanent toolbar control");
    NSVisualEffectView *stableColor=surface.objectColorWell;
    surface.paletteEditsSelection=YES; swatch.tag=2;
    [document.undo beginUndoGrouping]; [surface selectColor:swatch]; [document.undo endUndoGrouping];
    NSCAssert(([document.objects.firstObject[@"color"] isEqual:@[@1,@.57,@.24,@1]] && surface.objectColorWell==stableColor),@"attached color action updates selected text without replacing contextual controls");
    NSButton *font=NSButton.new; font.tag=1;
    [document.undo beginUndoGrouping]; [surface formatText:font]; [document.undo endUndoGrouping];
    NSCAssert(surface.contextTools==stablePill,@"formatting updates the existing contextual controls without replacing a button during tracking");
    for(NSButton *control in surface.contextTools.subviews) if([control isKindOfClass:NSButton.class]) {
        if(control.tag==1) NSCAssert([control.accessibilityValue isEqual:DPEaselFont(document.objects.firstObject).familyName],@"font accessibility value follows the current font");
        else if(control.tag<3) NSCAssert(control.continuous,@"size controls use native paced repeat while held");
    }
    NSDictionary *remembered=canvas.textStyle;
    [canvas selectTool:@"text"]; [canvas mouseDown:mouse(canvas,NSEventTypeLeftMouseDown,NSMakePoint(300,600),0,1)];
    NSCAssert([canvas.draft[@"font"] isEqual:remembered[@"font"]] && [canvas.draft[@"size"] isEqual:remembered[@"size"]],@"next text gesture retains the chosen font and size");
    NSEvent *escape=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil characters:@"\033" charactersIgnoringModifiers:@"\033" isARepeat:NO keyCode:53];
    [canvas keyDown:escape]; NSCAssert(!canvas.draft && [canvas.tool isEqual:@"select"],@"Escape cancels a draft and exits its drawing tool together");
    for(NSButton *button in surface.buttons) {
        NSCAssert(NSMaxX(button.frame)<=NSWidth(surface.toolbar.bounds),@"all tools fit narrow viewport");
        NSCAssert([button.accessibilityRole isEqual:NSAccessibilityRadioButtonRole] && [button.accessibilityValue boolValue]==[button.identifier isEqual:canvas.tool],@"assistive tools can identify the selected drawing tool");
    }
    for(NSString *appearance in @[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]) {
        window.appearance=[NSAppearance appearanceNamed:appearance];
        NSBitmapImageRep *pixels=[surface bitmapImageRepForCachingDisplayInRect:surface.bounds];
        [surface cacheDisplayInRect:surface.bounds toBitmapImageRep:pixels];
        NSCAssert(pixels.pixelsWide>0,@"native editor renders in light/dark without layout loop");
    }
    for(NSValue *region in DPEaselCursorRegions(canvas)) {
        NSRect toolbar=[canvas convertRect:surface.toolbar.bounds fromView:surface.toolbar];
        NSCAssert(NSIsEmptyRect(NSIntersectionRect(region.rectValue,toolbar)),@"drawing cursor regions never overlap the toolbar");
    }
    NSCAssert(DPEaselCursorOverChrome(canvas,[surface.toolbar convertPoint:NSMakePoint(10,10) toView:nil]),@"toolbar gaps also use the standard cursor");
    for(NSString *appearance in @[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]) {
        [[NSAppearance appearanceNamed:appearance] performAsCurrentDrawingAppearance:^{
            BOOL dark=[appearance isEqual:NSAppearanceNameDarkAqua];
            for(NSNumber *channel in @[@0,@1]) {
                NSColor *ink=[DPEaselObjectColor(@{@"color":@[channel,channel,channel,@1]}) colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
                NSCAssert(dark ? ink.redComponent>.7 : ink.redComponent<.3,@"explicit white and black adapt to the viewing theme");
            }
            NSColor *red=[DPEaselObjectColor(@{@"color":@[@1,@0,@0,@1]}) colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; NSCAssert(red.redComponent==1 && red.greenComponent==0,@"other colors keep their chosen values");
        }];
    }
    NSDictionary *outline=@{@"id":NSUUID.UUID.UUIDString,@"type":@"rectangle",@"outline":@YES,@"rect":@[@100,@100,@200,@200],@"z":@10};
    canvas.previewObjects=@[outline]; [canvas.selection removeAllObjects];
    NSCAssert(![canvas objectAtPoint:NSMakePoint(200,200)],@"unselected outline keeps empty interior transparent to hit testing");
    [canvas.selection addObject:outline[@"id"]]; NSCAssert([canvas objectAtPoint:NSMakePoint(200,200)]==outline,@"selected outline can be dragged from its interior");
    canvas.tool=@"select";
    NSCAssert([canvas interactionCursorAtPoint:NSMakePoint(200,200)]==[canvas drawingCursor],@"hovering a shape keeps the main selection cursor");
    canvas.moving=YES; canvas.draggingSelection=YES; NSCAssert([canvas interactionCursorAtPoint:NSMakePoint(200,200)]==NSCursor.closedHandCursor,@"dragging uses the native holding hand"); canvas.moving=NO; canvas.draggingSelection=NO;
    NSPoint handle=[DPEaselVisualHandles(outline,1).firstObject pointValue]; NSCAssert(handle.x==96 && handle.y==96,@"square handles are centered on the expanded selection outline");
    NSCAssert([canvas interactionCursorAtPoint:handle]!=[canvas drawingCursor],@"selection corners use directional resize cursors");
    canvas.previewObjects=nil;
    for(NSString *appearance in @[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]) {
        [[NSAppearance appearanceNamed:appearance] performAsCurrentDrawingAppearance:^{
            NSString *origin=DPEaselColorAppearance(NSAppearance.currentDrawingAppearance);
            for(NSNumber *channel in @[@0,@1]) {
                NSDictionary *ink=@{@"color":@[channel,channel,channel,@1],@"colorAppearance":origin};
                NSColor *same=[DPEaselObjectColor(ink) colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; NSCAssert(fabs(same.redComponent-channel.doubleValue)<.001,@"explicit black/white stays as chosen in its originating theme");
                NSString *other=[origin isEqual:@"dark"] ? NSAppearanceNameAqua : NSAppearanceNameDarkAqua;
                [[NSAppearance appearanceNamed:other] performAsCurrentDrawingAppearance:^{
                    NSColor *changed=[DPEaselObjectColor(ink) colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; NSCAssert(fabs(changed.redComponent-(1-channel.doubleValue))<.001,@"black/white inverts only when the viewing theme changes");
                }];
            }
        }];
    }
    [canvas selectTool:@"pen"]; [canvas resetCursorRects];
    [canvas selectTool:@"select"]; [DPEaselStore.shared flush];
    [surface removeFromSuperview]; [window close];
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: native seven-tool editor, Shift draw, move/undo, duplicate/delete, text session undo, fixed canvas, narrow toolbar and light/dark rendering");
} }
