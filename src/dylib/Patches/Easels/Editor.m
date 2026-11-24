#import "Canvas.h"
#import "ToolButton.h"
@implementation DPEaselEditorSurface
- (void)dealloc { [_shapeOptionsDelay invalidate]; [NSNotificationCenter.defaultCenter removeObserver:_scrollObserver]; }
- (BOOL)isFlipped { return YES; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; if(self.canvas) { [self refreshTools]; [NSNotificationCenter.defaultCenter postNotificationName:@"DPEaselHostAppearanceChanged" object:self]; } }
- (void)setFrameSize:(NSSize)size {
    BOOL changed = !NSEqualSizes(self.frame.size, size);
    [super setFrameSize:size];
    if (changed) self.needsLayout = YES;
}
- (void)layout {
    [super layout]; self.scroll.frame=self.bounds; [self.scroll layoutSubtreeIfNeeded]; [self fitSlideToViewport];
    self.toolbar.frame=NSMakeRect(16,MAX(0,NSHeight(self.bounds)-62),MIN(310,MAX(0,NSWidth(self.bounds)-148)),46);
    self.colorWell.frame=NSMakeRect(NSMaxX(self.toolbar.frame)+8,NSMinY(self.toolbar.frame),46,46);
    self.exportWell.frame=NSMakeRect(MAX(16,NSWidth(self.bounds)-62),MAX(0,NSHeight(self.bounds)-62),46,46);
    self.exportButton.frame=NSMakeRect(5,5,36,36);
    self.colorButton.frame=NSMakeRect(5,5,36,36);
    CGFloat button=MAX(0,MIN(36,(NSWidth(self.toolbar.bounds)-10-6*6)/7));
    CGFloat gap=self.buttons.count>1 ? MAX(0,(NSWidth(self.toolbar.bounds)-10-7*button)/6) : 0;
    for(NSUInteger i=0;i<self.buttons.count;i++) self.buttons[i].frame=NSMakeRect(5+i*(button+gap),5,button,36);
    [self refreshTools]; [self.window invalidateCursorRectsForView:self.canvas];
}
- (void)viewWillMoveToSuperview:(NSView *)newSuperview {
    if(!newSuperview) { [self.exportPopover close]; [self hideShapeOptions]; [self.palette close]; [self.canvas stopImageAnimations]; [self.canvas endText]; [self.canvas cancelGesture]; [self.canvas cancelImageImport]; }
    [super viewWillMoveToSuperview:newSuperview];
}
@end
NSView *DPEaselEditor(DPEaselDocument *document) {
    NSMutableArray *fitted=NSMutableArray.new;
    for(NSDictionary *object in document.objects) [fitted addObject:DPEaselGrowTitle(object)];
    if(![fitted isEqual:document.objects]) {
        [document.undo disableUndoRegistration]; [document replaceObjects:fitted action:@"Fit Heading"]; [document.undo enableUndoRegistration];
        [DPEaselStore.shared save:document completion:nil];
    }
    DPEaselEditorSurface *surface=DPEaselEditorSurface.new;
    surface.scroll=NSScrollView.new; surface.scroll.drawsBackground=YES; surface.scroll.backgroundColor=NSColor.textBackgroundColor;
    surface.scroll.hasVerticalScroller=YES; surface.scroll.hasHorizontalScroller=YES; surface.scroll.autohidesScrollers=YES;
    surface.scroll.allowsMagnification=NO;
    surface.canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,document.canvasSize.width,document.canvasSize.height)];
    surface.canvas.document=document; surface.scroll.documentView=surface.canvas; [surface addSubview:surface.scroll];
    surface.toolbar=NSVisualEffectView.new; surface.toolbar.material=NSVisualEffectMaterialPopover;
    surface.toolbar.blendingMode=NSVisualEffectBlendingModeWithinWindow;
    surface.toolbar.wantsLayer=YES; surface.toolbar.layer.cornerRadius=12; surface.toolbar.layer.masksToBounds=YES;
    surface.buttons=NSMutableArray.new;
    NSArray *tools=@[@"select",@"image",@"text",@"oval",@"rectangle",@"arrow",@"pen"];
    NSArray *symbols=@[@"cursorarrow",@"photo",@"textformat",@"circle",@"square",@"arrow.up.right",@"pencil.tip"];
    NSArray *names=@[@"Select (V)",@"Image (I)",@"Text (T)",@"Oval (O)",@"Rectangle (R)",@"Arrow (A)",@"Pen (P)"];
    for(NSUInteger i=0;i<tools.count;i++) {
        DPEaselToolButton *button=[DPEaselToolButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:nil] target:surface action:@selector(chooseTool:)];
        button.letter=@[@"V",@"I",@"T",@"O",@"R",@"A",@"P"][i];
        button.identifier=tools[i]; button.toolTip=names[i]; button.accessibilityLabel=names[i];
        button.bordered=NO; button.imagePosition=NSImageOnly;
        button.symbolConfiguration=[NSImageSymbolConfiguration configurationWithPointSize:19 weight:NSFontWeightRegular];
        [surface.toolbar addSubview:button]; [surface.buttons addObject:button];
    }
    [surface addSubview:surface.toolbar];
    surface.colorWell=NSVisualEffectView.new; surface.colorWell.material=NSVisualEffectMaterialPopover;
    surface.colorWell.blendingMode=NSVisualEffectBlendingModeWithinWindow; surface.colorWell.wantsLayer=YES;
    surface.colorWell.layer.cornerRadius=12; surface.colorWell.layer.masksToBounds=YES;
    surface.colorButton=[NSButton buttonWithTitle:@"●" target:surface action:@selector(showPalette:)];
    surface.colorButton.bordered=NO; surface.colorButton.font=[NSFont systemFontOfSize:25]; surface.colorButton.accessibilityLabel=@"Drawing color";
    [surface.colorWell addSubview:surface.colorButton]; [surface addSubview:surface.colorWell];
    surface.exportWell=NSVisualEffectView.new; surface.exportWell.material=NSVisualEffectMaterialPopover; surface.exportWell.blendingMode=NSVisualEffectBlendingModeWithinWindow;
    surface.exportWell.wantsLayer=YES; surface.exportWell.layer.cornerRadius=12;
    surface.exportButton=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"square.and.arrow.up" accessibilityDescription:nil] target:surface action:@selector(showExport:)];
    surface.exportButton.bordered=NO; surface.exportButton.contentTintColor=DPEaselAccent(surface); surface.exportButton.toolTip=@"Export or Share Easel"; surface.exportButton.accessibilityLabel=@"Export or Share Easel";
    [surface.exportWell addSubview:surface.exportButton]; [surface addSubview:surface.exportWell];
    __weak DPEaselEditorSurface *weak=surface;
    surface.canvas.selectionChanged=^{ [weak refreshTools]; };
    surface.scroll.contentView.postsBoundsChangedNotifications=YES;
    surface.scrollObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSViewBoundsDidChangeNotification object:surface.scroll.contentView queue:nil usingBlock:^(NSNotification *note){
        [weak updateContextTools];
    }];
    surface.accessibilityLabel=@"Easel Editor"; surface.accessibilityRole=NSAccessibilityGroupRole;
    return surface;
}
