#import "Canvas.h"
@implementation DPEaselEditorSurface (ObjectColor)
- (void)updateObjectColorControl {
    NSDictionary *selected=nil;
    if(self.canvas.selection.count==1) for(NSDictionary *object in self.canvas.document.objects)
        if([self.canvas.selection containsObject:object[@"id"]] && DPEaselObjectCanColor(object)) { selected=object; break; }
    BOOL hidden=!selected || self.canvas.moving || self.canvas.resizing>=0 || self.canvas.draft || self.canvas.marquee;
    self.objectColorWell.hidden=hidden; if(hidden) return;
    if(!self.objectColorWell) {
        self.objectColorWell=NSVisualEffectView.new; self.objectColorWell.material=NSVisualEffectMaterialPopover;
        self.objectColorWell.blendingMode=NSVisualEffectBlendingModeWithinWindow; self.objectColorWell.wantsLayer=YES;
        self.objectColorWell.layer.cornerRadius=10; self.objectColorWell.layer.masksToBounds=YES;
        self.objectColorButton=[NSButton buttonWithTitle:@"●" target:self action:@selector(showPalette:)];
        self.objectColorButton.bordered=NO; self.objectColorButton.font=[NSFont systemFontOfSize:23];
        self.objectColorButton.frame=NSMakeRect(0,0,36,36); self.objectColorButton.toolTip=@"Change selected item color";
        self.objectColorButton.accessibilityLabel=@"Selected item color";
        [self.objectColorWell addSubview:self.objectColorButton]; [self addSubview:self.objectColorWell];
    }
    NSRect anchor=[self convertRect:DPEaselObjectRect(selected) fromView:self.canvas];
    CGFloat x=NSMaxX(anchor)+8;
    if(x+36>NSWidth(self.bounds)-8) x=NSMinX(anchor)-44;
    x=MAX(8,MIN(x,NSWidth(self.bounds)-44));
    CGFloat y=MAX(8,MIN(NSMidY(anchor)-18,NSHeight(self.bounds)-106));
    self.objectColorWell.frame=NSMakeRect(x,y,36,36);
    DPEaselStyleColorWell(self.objectColorWell);
    self.objectColorButton.contentTintColor=DPEaselObjectColor(selected);
}
@end
