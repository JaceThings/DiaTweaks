#import "Library.h"
static void DPDrawInputChrome(NSView *view,NSControl *field) {
    NSBezierPath *shape = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(view.bounds,.5,.5) xRadius:11 yRadius:11];
    [[NSColor.controlBackgroundColor colorWithAlphaComponent:.24] setFill]; [shape fill];
    id editor = view.window.firstResponder;
    BOOL focused = editor == field || ([editor isKindOfClass:NSTextView.class] && (id)[(NSTextView *)editor delegate] == (id)field);
    [[(focused ? NSColor.labelColor : NSColor.labelColor) colorWithAlphaComponent:focused ? .32 : .12] setStroke]; shape.lineWidth = 1; [shape stroke];
}
@interface DPLibraryInputSurface : NSView
@property(weak) NSControl *field;
@end
@implementation DPLibraryInputSurface
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty { DPDrawInputChrome(self,self.field);
}
- (void)mouseDown:(NSEvent *)event {
    if ([self.field isKindOfClass:NSTextField.class]) [self.window makeFirstResponder:self.field];
    else [(NSButton *)self.field performClick:self];
    self.needsDisplay = YES;
}
@end
@interface DPLibraryFilterCell : NSPopUpButtonCell @end
@implementation DPLibraryFilterCell
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view {
    if([view.identifier isEqual:@"filterChip"]) frame=NSInsetRect(frame,6,4);
    NSImage *icon = [[NSImage imageWithSystemSymbolName:@"line.3.horizontal.decrease.circle" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[NSColor.secondaryLabelColor]]];
    NSRect image = NSMakeRect(NSMinX(frame)+3,NSMidY(frame)-8,16,16);
    [icon drawInRect:image fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    NSRect label = NSMakeRect(NSMinX(frame)+25,NSMidY(frame)-8,NSWidth(frame)-25,17);
    [self.selectedItem.title ?: @"All" drawInRect:label withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.labelColor}];
}
@end
@interface DPLibraryFilterButton : NSPopUpButton @end
@implementation DPLibraryFilterButton
+ (Class)cellClass { return DPLibraryFilterCell.class; }
- (void)drawRect:(NSRect)rect { if([self.identifier isEqual:@"filterChip"]) DPDrawInputChrome(self,self); [super drawRect:rect]; }
@end
void DPLibraryBuildInputSurfaces(DPLibraryController *controller) {
    controller.searchChrome = [DPLibraryInputSurface new]; controller.filterChrome = [DPLibraryInputSurface new];
    [controller.view addSubview:controller.searchChrome]; [controller.view addSubview:controller.filterChrome];
    [controller.searchChrome addSubview:controller.search]; [controller.filterChrome addSubview:controller.filter];
    [(DPLibraryInputSurface *)controller.searchChrome setField:controller.search];
    [(DPLibraryInputSurface *)controller.filterChrome setField:controller.filter];
    controller.search.bezeled = NO; controller.search.drawsBackground = NO;
    controller.search.focusRingType = NSFocusRingTypeNone;
    [(NSSearchFieldCell *)controller.search.cell setSearchButtonCell:nil];
    NSImageView *searchIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(10,10,16,16)];
    searchIcon.image = [NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:nil];
    searchIcon.contentTintColor = NSColor.secondaryLabelColor; [controller.searchChrome addSubview:searchIcon];
    controller.search.font = [NSFont systemFontOfSize:13];
    controller.filter.bordered = NO; controller.filter.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    controller.filter.menu.autoenablesItems = NO;
    NSPopUpButtonCell *cell = controller.filter.cell; cell.usesItemFromMenu = NO; cell.arrowPosition = NSPopUpNoArrow;
    cell.imagePosition = NSImageLeft;
    cell.image = [[NSImage imageWithSystemSymbolName:@"line.3.horizontal.decrease.circle" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightRegular]];
    cell.title = @"Filter";
}

NSPopUpButton *DPLibraryMakeFilterButton(id target,SEL action) {
    NSPopUpButton *button=[[DPLibraryFilterButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    button.identifier=@"filterChip"; button.bordered=NO; button.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; button.target=target; button.action=action;
    button.menu.autoenablesItems=NO; NSPopUpButtonCell *cell=button.cell; cell.usesItemFromMenu=NO; cell.arrowPosition=NSPopUpNoArrow;
    return button;
}
