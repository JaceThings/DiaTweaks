#import "Canvas.h"
@interface DPEaselTextView : NSTextView
@property NSUndoManager *typingUndo;
@property(weak) DPEaselCanvas *canvas;
@end
@implementation DPEaselTextView
- (NSUndoManager *)undoManager { if(!_typingUndo) _typingUndo=NSUndoManager.new; return _typingUndo; }
- (void)mouseDown:(NSEvent *)event {
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
    if(event.clickCount==2 && !NSPointInRect(point,NSInsetRect(self.bounds,7,7))) {
        DPEaselCanvas *canvas=self.canvas; NSString *identifier=canvas.textObjectID;
        [canvas endText];
        for(NSDictionary *object in canvas.document.objects) if([object[@"id"] isEqual:identifier]) { [canvas fitText:object]; break; }
        return;
    }
    [super mouseDown:event];
}
- (void)keyDown:(NSEvent *)event {
    if(event.keyCode==53 && !self.hasMarkedText) { DPEaselCanvas *canvas=self.canvas; [canvas selectTool:@"select"]; return; }
    [super keyDown:event];
}
@end
@implementation DPEaselCanvas (Text)
- (void)beginText:(NSDictionary *)object {
    [DPEaselHost finishEditingDocument:self.document]; [self endText]; self.originalText=object; self.textObjectID=object[@"id"];
    DPEaselTextView *text=[[DPEaselTextView alloc] initWithFrame:DPEaselObjectRect(object)];
    text.canvas=self; text.delegate=self; text.richText=NO; text.drawsBackground=NO;
    text.alignment=[object[@"isTitle"] boolValue] ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    text.font=DPEaselFont(object); text.textColor=DPEaselObjectColor(object); text.textContainerInset=NSMakeSize(4,4);
    text.horizontallyResizable=NO; text.verticallyResizable=NO; text.textContainer.widthTracksTextView=YES;
    text.textContainer.lineFragmentPadding=0; // Match the canvas' four-point text inset and wrapping.
    text.allowsUndo=YES; text.continuousSpellCheckingEnabled=YES; text.string=object[@"text"] ?: @"";
    self.textEditor=text; [self addSubview:text]; [self.window makeFirstResponder:text];
    if([object[@"placeholder"] boolValue]) [text setSelectedRange:NSMakeRange(0,text.string.length)];
    self.needsDisplay=YES;
}
- (void)textDidChange:(NSNotification *)notification {
    if(notification.object!=self.textEditor || self.document.deleted) return;
    NSMutableArray *objects=[self.document.objects mutableCopy];
    for(NSUInteger i=0;i<objects.count;i++) if([objects[i][@"id"] isEqual:self.textObjectID]) {
        NSMutableDictionary *object=[objects[i] mutableCopy]; object[@"text"]=self.textEditor.string; object[@"placeholder"]=@NO;
        objects[i]=DPEaselGrowTitle(object); self.textEditor.frame=DPEaselObjectRect(objects[i]); break;
    }
    [self.document.undo disableUndoRegistration]; [self.document replaceObjects:objects action:@"Edit Text"]; [self.document.undo enableUndoRegistration];
    [self.textSave invalidate]; __weak DPEaselCanvas *weak=self;
    self.textSave=[NSTimer timerWithTimeInterval:.35 repeats:NO block:^(NSTimer *timer) {
        DPEaselCanvas *canvas=weak; if(canvas && !canvas.document.deleted) [DPEaselStore.shared save:canvas.document completion:nil]; canvas.textSave=nil;
    }];
    [NSRunLoop.mainRunLoop addTimer:self.textSave forMode:NSRunLoopCommonModes];
}
- (void)endText {
    if(!self.textEditor) return;
    [self.textSave invalidate]; self.textSave=nil;
    NSDictionary *original=self.originalText;
    NSMutableArray *before=[self.document.objects mutableCopy]; BOOL changed=NO;
    for(NSUInteger i=0;i<before.count;i++) if([before[i][@"id"] isEqual:self.textObjectID]) {
        changed=![before[i] isEqual:original]; before[i]=original; break;
    }
    if(changed && !self.document.deleted) {
        [self.document.undo registerUndoWithTarget:self.document handler:^(DPEaselDocument *doc){ [doc replaceObjects:before action:@"Edit Text"]; }];
        [self.document.undo setActionName:@"Edit Text"];
        [DPEaselStore.shared save:self.document completion:nil];
    }
    [self.textEditor removeFromSuperview]; self.textEditor=nil; self.textObjectID=nil; self.originalText=nil;
    [self.window makeFirstResponder:self]; self.needsDisplay=YES;
}
- (void)fitText:(NSDictionary *)object {
    if(![object[@"type"] isEqual:@"text"]) return;
    [self endText];
    NSRect frame=DPEaselObjectRect(object);
    NSRect measured=[object[@"text"] boundingRectWithSize:NSMakeSize(MAX(40,NSWidth(self.bounds)-frame.origin.x-24),CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:DPEaselFont(object)}];
    frame.size=NSMakeSize(MAX(40,ceil(measured.size.width)+12),MAX(24,ceil(measured.size.height)+12));
    NSMutableArray *objects=[self.document.objects mutableCopy];
    for(NSUInteger i=0;i<objects.count;i++) if([objects[i][@"id"] isEqual:object[@"id"]]) {
        NSMutableDictionary *fit=[objects[i] mutableCopy]; fit[@"rect"]=DPEaselRectArray(frame); objects[i]=fit; break;
    }
    [self commit:objects action:@"Fit Text"];
}
@end
