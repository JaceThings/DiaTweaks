#import "TaskView.h"
@interface DPTaskCheckButton : NSButton @end
@implementation DPTaskCheckButton
- (void)drawRect:(NSRect)rect {
    NSImage *image=[self.image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[self.contentTintColor ?: NSColor.secondaryLabelColor]]];
    [image drawInRect:NSMakeRect(NSMidX(self.bounds)-10,NSMidY(self.bounds)-10,20,20) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:self.highlighted ? .65 : 1 respectFlipped:YES hints:nil];
}
@end
@interface DPTaskLabel : NSTextField @end
@implementation DPTaskLabel
- (void)mouseDown:(NSEvent *)event { DPTaskCell *cell=(id)self.superview; if(cell.editing) [super mouseDown:event]; else [cell startEditing:self]; }
- (NSMenu *)menuForEvent:(NSEvent *)event { return [self.superview menuForEvent:event]; }
@end
@implementation DPTaskCell { NSTrackingArea *_tracking; CALayer *_hoverLayer; }
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.wantsLayer=YES; _hoverLayer=CALayer.layer; _hoverLayer.cornerRadius=11; _hoverLayer.cornerCurve=kCACornerCurveContinuous;
        [self.layer insertSublayer:_hoverLayer atIndex:0];
        self.check=[DPTaskCheckButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"circle" accessibilityDescription:nil] target:nil action:NULL]; self.check.bordered=NO; [self addSubview:self.check];
        NSTextField *label=DPTaskLabel.new; label.editable=NO; label.selectable=NO; label.bordered=NO; label.drawsBackground=NO; label.focusRingType=NSFocusRingTypeNone; label.font=[NSFont systemFontOfSize:14];
        label.maximumNumberOfLines=2; [self addSubview:label]; self.textField=label;
    } return self;
}
- (BOOL)isFlipped { return YES; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if(_tracking) [self removeTrackingArea:_tracking];
    _tracking=[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect owner:self userInfo:nil]; [self addTrackingArea:_tracking];
    [self dpLibraryUpdatePointerHover];
}
- (void)setFrameSize:(NSSize)size { [super setFrameSize:size]; [self dpLibraryUpdatePointerHover]; }
- (void)dpLibraryUpdatePointerHover {
    NSRect area=self.bounds;
    NSClipView *clip=self.owner.scroll.contentView;
    if(clip && self.superview) {
        // AppKit insets the cell inside a full-width table. Constrain the
        // highlight to this scroll viewport, never ancestor visibleRects
        // that temporarily narrow while Library slides into view.
        NSRect viewport=[self convertRect:clip.bounds fromView:clip];
        CGFloat left=MAX(NSMinX(area),NSMinX(viewport)),right=MIN(NSMaxX(area),NSMaxX(viewport));
        area.origin.x=left; area.size.width=MAX(0,right-left);
    }
    area=NSInsetRect(area,2,2); area.size.width=MAX(0,area.size.width); area.size.height=MAX(0,area.size.height);
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    _hoverLayer.frame=area;
    _hoverLayer.backgroundColor=DPLibraryPointerInside(self) ? [NSColor.labelColor colorWithAlphaComponent:.045].CGColor : nil;
    [CATransaction commit];
}
- (void)mouseEntered:(NSEvent *)event { DPLibraryReconcileHover(self.owner.table ?: self); }
- (void)mouseExited:(NSEvent *)event { [self dpLibraryUpdatePointerHover]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; if(self.record) self.record=self.record; [self dpLibraryUpdatePointerHover]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; if(self.record) self.record=self.record; [self dpLibraryUpdatePointerHover]; }
- (void)setRecord:(NSDictionary *)record {
    if(self.editing) return;
    _record=record; BOOL completed=[record[@"completed"] boolValue];
    self.check.identifier=record[@"id"]; self.check.accessibilityLabel=[NSString stringWithFormat:@"%@: %@",completed ? @"Mark incomplete" : @"Complete",record[@"text"]];
    self.check.image=[NSImage imageWithSystemSymbolName:completed ? @"checkmark.circle.fill" : @"circle" accessibilityDescription:nil];
    self.check.contentTintColor=completed ? DPLibraryAccentColor(self.window) : NSColor.secondaryLabelColor;
    self.textField.attributedStringValue=[[NSAttributedString alloc] initWithString:record[@"text"] attributes:@{
        NSFontAttributeName:[NSFont systemFontOfSize:14],NSForegroundColorAttributeName:completed ? NSColor.secondaryLabelColor : NSColor.labelColor,
        NSStrikethroughStyleAttributeName:@(completed ? NSUnderlineStyleSingle : NSUnderlineStyleNone)}];
    self.needsLayout=YES; self.needsDisplay=YES;
}
- (void)layout {
    [super layout]; [self dpLibraryUpdatePointerHover]; self.check.frame=NSMakeRect(6,(NSHeight(self.bounds)-28)/2,28,28);
    NSSize size=[self.textField sizeThatFits:NSMakeSize(MAX(0,NSWidth(self.bounds)-48),40)];
    self.textField.frame=NSMakeRect(38,MAX(6,(NSHeight(self.bounds)-MIN(40,size.height))/2),MAX(0,NSWidth(self.bounds)-48),MIN(40,size.height));
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu=NSMenu.new; menu.autoenablesItems=NO;
    NSArray *names=self.deletedItem ? @[@"Restore"] : @[@"Edit",@"Delete"];
    NSArray *actions=self.deletedItem ? @[@"restoreTask:"] : @[@"startEditing:",@"deleteTask:"];
    for(NSUInteger i=0;i<names.count;i++) { NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:names[i] action:NSSelectorFromString(actions[i]) keyEquivalent:@""]; item.target=self; item.enabled=self.owner.allowed; [menu addItem:item]; } return menu;
}
- (void)startEditing:(id)sender {
    if(self.deletedItem || !self.owner.allowed || self.owner.removing) return;
    self.editing=YES; self.textField.editable=YES; self.textField.selectable=YES;
    self.textField.stringValue=self.record[@"text"]; self.textField.delegate=(id)self;
    self.textField.target=self; self.textField.action=@selector(commitEditing:);
    [self.window makeFirstResponder:self.textField];
    NSTextView *editor=(id)self.textField.currentEditor;
    editor.drawsBackground=NO; editor.backgroundColor=NSColor.clearColor; editor.insertionPointColor=NSColor.labelColor;
    [editor setSelectedRange:NSMakeRange(self.textField.stringValue.length,0)];
}
- (void)commitEditing:(id)sender {
    if(!self.editing) return;
    NSString *text=self.textField.stringValue,*identifier=self.record[@"id"]; self.editing=NO;
    self.textField.editable=NO; self.textField.selectable=NO;
    [self.owner.store edit:text identifier:identifier]; self.record=self.record; [self.owner reload];
}
- (void)controlTextDidEndEditing:(NSNotification *)note { [self commitEditing:self]; }
- (BOOL)control:(NSControl *)control textView:(NSTextView *)view doCommandBySelector:(SEL)selector {
    if(selector!=@selector(cancelOperation:)) return NO;
    self.textField.stringValue=self.record[@"text"]; [self commitEditing:self]; [self.window makeFirstResponder:self.owner.input]; return YES;
}
- (void)deleteTask:(id)sender {
    if(!self.owner.allowed || self.owner.removing) return;
    NSString *identifier=self.record[@"id"]; DPTaskStore *store=self.owner.store;
    [self.owner performRemoval:@[self] mutation:^{ [store remove:identifier]; }];
}
- (void)restoreTask:(id)sender { if(self.owner.allowed) [self.owner.store restore:self.record[@"id"]]; }
@end
