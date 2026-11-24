#import "Canvas.h"
static NSArray *DPColors(void) {
    return @[@[@1,@1,@1,@1],@[@1,@.83,@.16,@1],@[@1,@.57,@.24,@1],@[@.98,@.23,@.10,@1],@[@0,@.84,@.52,@1],@[@.05,@.45,@.02,@1],
        @[@0,@0,@0,@1],@[@.65,@.65,@.65,@1],@[@.7,@0,@.65,@1],@[@0,@.72,@.88,@1],@[@.23,@.17,@.95,@1]];
}
@implementation DPEaselEditorSurface (Palette)
- (void)showPalette:(NSButton *)button {
    [self.canvas endText];
    self.paletteEditsSelection=NO;
    for(NSDictionary *object in self.canvas.document.objects) if([self.canvas.selection containsObject:object[@"id"]] && DPEaselObjectCanColor(object)) self.paletteEditsSelection=YES;
    [self.palette close]; self.palette=NSPopover.new; self.palette.behavior=NSPopoverBehaviorTransient;
    NSViewController *controller=NSViewController.new; controller.view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,232,94)];
    NSArray *selectedColor=self.canvas.color;
    if(self.canvas.selection.count==1) for(NSDictionary *object in self.canvas.document.objects)
        if([self.canvas.selection containsObject:object[@"id"]] && DPEaselObjectCanColor(object)) { selectedColor=object[@"color"] ?: selectedColor; break; }
    NSArray *colors=DPColors();
    for(NSUInteger i=0;i<colors.count;i++) {
        NSArray *rgba=colors[i]; NSButton *swatch=[NSButton buttonWithTitle:[selectedColor isEqual:rgba] ? @"✓" : @"" target:self action:@selector(selectColor:)];
        swatch.tag=i; swatch.frame=NSMakeRect(14+(i%6)*35,55-(i/6)*36,24,24); swatch.bordered=NO; swatch.wantsLayer=YES;
        swatch.layer.cornerRadius=12; swatch.layer.borderWidth=.5; swatch.layer.borderColor=[NSColor.grayColor colorWithAlphaComponent:.3].CGColor;
        swatch.layer.backgroundColor=[NSColor colorWithSRGBRed:[rgba[0] doubleValue] green:[rgba[1] doubleValue] blue:[rgba[2] doubleValue] alpha:1].CGColor;
        swatch.contentTintColor=i==0 || i==1 || i==7 ? NSColor.blackColor : NSColor.whiteColor;
        swatch.accessibilityLabel=@[@"White",@"Yellow",@"Orange",@"Red",@"Green",@"Dark Green",@"Black",@"Gray",@"Purple",@"Cyan",@"Blue"][i];
        [controller.view addSubview:swatch];
    }
    self.palette.contentViewController=controller;
    [self.palette showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMaxY];
}
- (void)selectColor:(NSButton *)button {
    self.canvas.color=DPColors()[button.tag]; self.canvas.colorAppearance=DPEaselColorAppearance(self.effectiveAppearance); NSMutableArray *objects=[self.canvas.document.objects mutableCopy];
    self.canvas.toolColors[self.canvas.lastDrawingTool ?: @"text"]=self.canvas.color;
    self.canvas.toolColorAppearances[self.canvas.lastDrawingTool ?: @"text"]=self.canvas.colorAppearance;
    for(NSUInteger i=0;i<objects.count;i++) if(self.paletteEditsSelection && [self.canvas.selection containsObject:objects[i][@"id"]] && DPEaselObjectCanColor(objects[i])) {
        NSMutableDictionary *object=[objects[i] mutableCopy]; object[@"color"]=self.canvas.color; object[@"semanticInk"]=@NO; object[@"colorAppearance"]=self.canvas.colorAppearance; objects[i]=object;
        self.canvas.toolColors[object[@"type"]]=self.canvas.color; self.canvas.toolColorAppearances[object[@"type"]]=self.canvas.colorAppearance;
    }
    if(self.paletteEditsSelection) [self.canvas commit:objects action:@"Change Color"];
    [self refreshTools]; [self.palette close];
}
@end
