#import "Canvas.h"
#import "ToolButton.h"
@implementation DPEaselEditorSurface (ShapeOptions)
- (void)hideShapeOptions {
    [self.shapeOptionsDelay invalidate]; self.shapeOptionsDelay=nil;
    [self.shapeOptions removeFromSuperview]; self.shapeOptions=nil;
}
- (void)updateShapeOptions {
    NSString *tool=self.canvas.tool; NSDictionary *selected=nil;
    if([tool isEqual:@"select"] && self.canvas.selection.count==1) for(NSDictionary *object in self.canvas.document.objects)
        if([self.canvas.selection containsObject:object[@"id"]]) { selected=object; tool=object[@"type"]; break; }
    BOOL active=(selected || !self.canvas.selection.count) && [@[@"oval",@"rectangle"] containsObject:tool] && !self.canvas.draft && !self.canvas.moving && self.canvas.resizing<0;
    NSString *context=active ? [NSString stringWithFormat:@"%@:%@:%lu",tool,selected[@"id"] ?: @"next",(unsigned long)self.canvas.importGeneration] : @"";
    if(![context isEqual:self.shapeOptionsContext]) {
        [self hideShapeOptions]; self.shapeOptionsContext=context;
        if(active) {
            self.shapeOptions=NSVisualEffectView.new; self.shapeOptions.material=NSVisualEffectMaterialPopover;
            self.shapeOptions.blendingMode=NSVisualEffectBlendingModeWithinWindow; self.shapeOptions.wantsLayer=YES;
            self.shapeOptions.layer.cornerRadius=12; self.shapeOptions.layer.masksToBounds=YES;
            for(NSUInteger i=0;i<2;i++) {
                NSString *symbol=[tool isEqual:@"oval"] ? @"circle" : @"square";
                if(!i) symbol=[symbol stringByAppendingString:@".fill"];
                NSButton *button=[DPEaselToolButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] target:self action:@selector(chooseShapeStyle:)];
                button.tag=i; button.identifier=tool; button.bordered=NO; button.frame=NSMakeRect(5,5+i*40,36,36);
                button.symbolConfiguration=[NSImageSymbolConfiguration configurationWithPointSize:19 weight:NSFontWeightRegular];
                button.accessibilityLabel=i ? @"Outline shape" : @"Filled shape"; button.toolTip=button.accessibilityLabel;
                [self.shapeOptions addSubview:button];
            }
            [self addSubview:self.shapeOptions];
            __weak DPEaselEditorSurface *weak=self;
            self.shapeOptionsDelay=[NSTimer scheduledTimerWithTimeInterval:3.5 repeats:YES block:^(NSTimer *timer){
                DPEaselEditorSurface *surface=weak; NSView *options=surface.shapeOptions;
                NSPoint point=[options convertPoint:options.window.mouseLocationOutsideOfEventStream fromView:nil];
                if(options.window.isKeyWindow && NSMouseInRect(point,options.bounds,options.isFlipped)) return;
                [surface hideShapeOptions];
            }];
        }
    }
    BOOL outline=selected ? [selected[@"outline"] boolValue] : DPEaselShapeOutline(tool);
    for(NSButton *button in self.shapeOptions.subviews) { button.state=button.tag==outline; button.contentTintColor=DPEaselAccent(self); }
    for(NSButton *button in self.buttons) if([button.identifier isEqual:tool]) {
        NSRect anchor=[self convertRect:button.bounds fromView:button];
        self.shapeOptions.frame=NSMakeRect(MAX(8,MIN(NSMidX(anchor)-23,NSWidth(self.bounds)-54)),MAX(8,NSMinY(self.toolbar.frame)-94),46,86); break;
    }
}
- (void)chooseShapeStyle:(NSButton *)sender {
    BOOL outline=sender.tag!=0; DPEaselRememberShapeOutline(sender.identifier,outline);
    NSMutableArray *objects=[self.canvas.document.objects mutableCopy]; BOOL changed=NO;
    for(NSUInteger i=0;i<objects.count;i++) if([self.canvas.selection containsObject:objects[i][@"id"]] && [objects[i][@"type"] isEqual:sender.identifier]) {
        NSMutableDictionary *object=[objects[i] mutableCopy]; object[@"outline"]=@(outline); objects[i]=object; changed=YES;
    }
    if(changed) [self.canvas commit:objects action:@"Change Shape Style"];
    [self updateShapeOptions]; [self.window makeFirstResponder:self.canvas];
}
@end
