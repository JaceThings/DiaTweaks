#import "LibraryUI.h"
#import "Canvas.h"
@implementation DPEaselCard
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) { self.wantsLayer=YES; self.layer.cornerRadius=14; }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (BOOL)isAccessibilityElement { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if(self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking=[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect owner:self userInfo:nil]; [self addTrackingArea:self.tracking];
}
- (void)reconcileHover {
    NSPoint point=[self convertPoint:self.window.mouseLocationOutsideOfEventStream fromView:nil];
    self.hovered=self.window.isKeyWindow && !self.hiddenOrHasHiddenAncestor && NSMouseInRect(point,self.visibleRect,self.isFlipped);
}
- (void)mouseEntered:(NSEvent *)event { for(DPEaselCard *card in self.superview.subviews) [card reconcileHover]; }
- (void)mouseExited:(NSEvent *)event { [self reconcileHover]; }
- (void)setHovered:(BOOL)hovered {
    if(_hovered==hovered) return; _hovered=hovered;
    self.wantsLayer=YES; self.layer.cornerRadius=14;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.layer.backgroundColor=hovered ? [NSColor.labelColor colorWithAlphaComponent:.07].CGColor : nil;
    [CATransaction commit]; self.needsDisplay=YES;
}
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; self.hovered=NO; self.needsDisplay=YES; }
- (void)drawRect:(NSRect)dirty {
    NSRect card=NSInsetRect(self.bounds,8,8);
    NSBezierPath *paper=[NSBezierPath bezierPathWithRoundedRect:card xRadius:9 yRadius:9];
    [[NSColor.windowBackgroundColor colorWithAlphaComponent:.85] setFill]; [paper fill];
    [[NSColor.whiteColor colorWithAlphaComponent:.7] setStroke]; paper.lineWidth=3; [paper stroke];
    NSImage *mark=[[NSImage imageWithSystemSymbolName:@"pencil.and.outline" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[DPEaselAccent(self)]]];
    [mark drawInRect:NSMakeRect(21,NSHeight(self.bounds)-83,22,22) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    NSMutableParagraphStyle *paragraph=NSMutableParagraphStyle.new; paragraph.lineBreakMode=NSLineBreakByTruncatingTail;
    [self.record[@"title"] drawWithRect:NSMakeRect(21,NSHeight(self.bounds)-56,MAX(20,NSWidth(self.bounds)-42),44) options:NSStringDrawingUsesLineFragmentOrigin
        attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:17 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor,NSParagraphStyleAttributeName:paragraph}];
}
- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    if(!self.trashed) [(DPEaselLibraryContent *)self.owner openCard:self];
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu=NSMenu.new;
    if(self.trashed) {
        NSMenuItem *restore=[[NSMenuItem alloc] initWithTitle:@"Restore Easel" action:@selector(restoreFromMenu:) keyEquivalent:@""]; restore.target=self; [menu addItem:restore]; return menu;
    }
    NSMenuItem *rename=[[NSMenuItem alloc] initWithTitle:@"Rename Easel…" action:@selector(renameFromMenu:) keyEquivalent:@""]; rename.target=self; [menu addItem:rename];
    NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:@"Delete Easel" action:@selector(deleteFromMenu:) keyEquivalent:@""];
    item.target=self; [menu addItem:item]; return menu;
}
- (void)renameFromMenu:(id)sender {
    DPEaselDocument *document=[DPEaselStore.shared load:self.record[@"id"] error:nil];
    if(document) DPEaselPresentRename(self.window,document);
}
- (void)deleteFromMenu:(id)sender { [(DPEaselLibraryContent *)self.owner deleteCard:self]; }
- (void)restoreFromMenu:(id)sender { [(DPEaselLibraryContent *)self.owner restoreCard:self]; }
- (NSUndoManager *)undoManager { return [(DPEaselLibraryContent *)self.owner undo]; }
- (void)undo:(id)sender { [self.undoManager undo]; }
- (void)redo:(id)sender { [self.undoManager redo]; }
- (BOOL)accessibilityPerformPress {
    if(self.trashed) [self restoreFromMenu:nil]; else [(DPEaselLibraryContent *)self.owner openCard:self]; return YES;
}
@end
