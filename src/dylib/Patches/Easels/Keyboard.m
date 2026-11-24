#import "Canvas.h"
@implementation DPEaselCanvas (Keyboard)
- (void)keyDown:(NSEvent *)event {
    if(event.keyCode==53) { [self selectTool:@"select"]; return; }
    if(event.modifierFlags&(NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption)) { [super keyDown:event]; return; }
    if([self handleSelectionKey:event]) return;
    if(event.keyCode==51 || event.keyCode==117) { [self delete:nil]; return; }
    NSDictionary *tools=@{@"v":@"select",@"t":@"text",@"o":@"oval",@"r":@"rectangle",@"a":@"arrow",@"p":@"pen"};
    NSString *key=event.charactersIgnoringModifiers.lowercaseString,*tool=tools[key];
    if(tool) { [self selectTool:tool]; return; }
    if([key isEqual:@"i"]) {
        NSView *view=self.superview; while(view && ![view isKindOfClass:DPEaselEditorSurface.class]) view=view.superview;
        [(DPEaselEditorSurface *)view chooseImage:nil]; return;
    }
    [super keyDown:event];
}
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if(self.window.firstResponder!=self || !(event.modifierFlags&NSEventModifierFlagCommand)) return [super performKeyEquivalent:event];
    if(event.modifierFlags&(NSEventModifierFlagControl|NSEventModifierFlagOption)) return [super performKeyEquivalent:event];
    NSString *key=event.charactersIgnoringModifiers.lowercaseString;
    if((event.modifierFlags&NSEventModifierFlagShift) && ![key isEqual:@"z"]) return [super performKeyEquivalent:event];
    if([key isEqual:@"z"]) { [DPEaselHost finishEditingDocument:self.document]; if(event.modifierFlags&NSEventModifierFlagShift) [self.document.undo redo]; else [self.document.undo undo]; [DPEaselStore.shared save:self.document completion:nil]; return YES; }
    if([key isEqual:@"a"]) { [self selectAll:nil]; return YES; }
    if([key isEqual:@"d"]) { [self duplicate:nil]; return YES; }
    if([key isEqual:@"c"]) { [self copy:nil]; return YES; }
    if([key isEqual:@"x"]) { [self cut:nil]; return YES; }
    if([key isEqual:@"v"]) { [self paste:nil]; return YES; }
    return [super performKeyEquivalent:event];
}
@end
