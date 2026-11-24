#import "Canvas.h"
#import "TextSizeButton.h"
@implementation DPEaselEditorSurface (TextControls)
- (void)updateContextTools {
    [self updateObjectColorControl];
    NSDictionary *selected=nil;
    if(self.canvas.selection.count==1) for(NSDictionary *object in self.canvas.document.objects) if([self.canvas.selection containsObject:object[@"id"]]) { selected=object; break; }
    BOOL text=[selected[@"type"] isEqual:@"text"];
    if(!text || self.canvas.moving || self.canvas.resizing>=0 || self.canvas.draft || self.canvas.marquee) {
        [self.contextTools removeFromSuperview]; self.contextTools=nil; self.contextSignature=nil; return;
    }
    NSString *identifier=selected[@"id"];
    if(![self.contextSignature isEqual:identifier]) { [self.contextTools removeFromSuperview]; self.contextTools=nil; self.contextSignature=identifier; }
    NSVisualEffectView *pill=(NSVisualEffectView *)self.contextTools;
    if(!pill) {
        pill=NSVisualEffectView.new; pill.material=NSVisualEffectMaterialPopover; pill.blendingMode=NSVisualEffectBlendingModeWithinWindow;
        pill.wantsLayer=YES; pill.layer.cornerRadius=10; pill.layer.masksToBounds=YES;
        NSArray *titles=@[@"+",@"Aa",@"−"],*labels=@[@"Increase text size",@"Cycle font",@"Decrease text size"];
        for(NSUInteger i=0;i<titles.count;i++) {
            NSButton *button=[(i==1 ? NSButton.class : DPEaselTextSizeButton.class) buttonWithTitle:titles[i] target:self action:@selector(formatText:)];
            button.tag=i; button.frame=NSMakeRect(0,46+(titles.count-1-i)*36,36,36); button.bordered=NO;
            button.font=[NSFont systemFontOfSize:18 weight:NSFontWeightMedium]; button.toolTip=labels[i]; button.accessibilityLabel=labels[i];
            if(i!=1) { button.continuous=YES; [button setPeriodicDelay:.4 interval:.1]; ((DPEaselTextSizeButton *)button).canvas=self.canvas; }
            [pill addSubview:button];
        }
        NSBox *divider=NSBox.new; divider.boxType=NSBoxSeparator; divider.frame=NSMakeRect(7,41,22,1); [pill addSubview:divider];
        NSButton *fit=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.down.right.and.arrow.up.left" accessibilityDescription:@"Fit text box"] target:self action:@selector(fitSelectedText:)];
        fit.tag=3; fit.bordered=NO; fit.frame=NSMakeRect(0,0,36,36); fit.toolTip=@"Fit text box to text"; fit.accessibilityLabel=@"Fit text box to text"; [pill addSubview:fit];
        [self addSubview:pill]; self.contextTools=pill;
    }
    NSRect anchor=[self convertRect:DPEaselObjectRect(selected) fromView:self.canvas];
    CGFloat height=154;
    pill.frame=NSMakeRect(MAX(8,MIN(NSMinX(anchor)-44,NSWidth(self.bounds)-44)),MAX(8,MIN(NSMinY(anchor),NSHeight(self.bounds)-height-70)),36,height);
    for(NSView *child in pill.subviews) { if(![child isKindOfClass:NSButton.class]) continue; NSButton *button=(NSButton *)child;
        if(button.tag==1) { NSString *family=DPEaselFont(selected).familyName; button.toolTip=[NSString stringWithFormat:@"Cycle font — %@",family]; button.accessibilityValue=family; }
        button.contentTintColor=button.tag==1 ? NSColor.labelColor : DPEaselAccent(self);
    }
}
- (void)fitSelectedText:(id)sender {
    [self.canvas endText];
    for(NSDictionary *object in self.canvas.document.objects) if([self.canvas.selection containsObject:object[@"id"]] && [object[@"type"] isEqual:@"text"]) { [self.canvas fitText:object]; break; }
}
- (void)formatText:(NSButton *)button {
    [self.canvas endText];
    NSMutableArray *objects=[self.canvas.document.objects mutableCopy];
    for(NSUInteger i=0;i<objects.count;i++) if([self.canvas.selection containsObject:objects[i][@"id"]] && [objects[i][@"type"] isEqual:@"text"]) {
        NSMutableDictionary *object=[objects[i] mutableCopy];
        if(button.tag==1) {
            NSArray *fonts=@[@"sans",@"serif",@"rounded",@"script",@"mono"];
            NSUInteger index=[fonts indexOfObject:object[@"font"] ?: @"sans"]; object[@"font"]=fonts[index==NSNotFound ? 0 : (index+1)%fonts.count];
        } else object[@"size"]=@(MAX(8,MIN(240,[object[@"size"] doubleValue]*(button.tag==0 ? 1.2 : 1/1.2))));
        NSRect frame=DPEaselObjectRect(object);
        frame.size.height=MAX(frame.size.height,ceil(DPEaselFont(object).ascender-DPEaselFont(object).descender)+12);
        object[@"rect"]=DPEaselRectArray(frame);
        objects[i]=DPEaselGrowTitle(object);
        self.canvas.textStyle=@{@"font":object[@"font"] ?: @"sans",@"size":object[@"size"] ?: @24};
    }
    [self.canvas commit:objects action:button.tag==1 ? @"Change Font" : @"Change Text Size"];
}
@end
