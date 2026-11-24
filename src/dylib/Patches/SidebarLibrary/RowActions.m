#import "Library.h"
@interface DPLibraryActionCell : NSTableCellView
@property NSTrackingArea *tracking;
@property NSArray<NSButton *> *actions;
@property BOOL rowHovered;
@end
@implementation DPLibraryActionCell
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if (self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking=[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingInVisibleRect|NSTrackingActiveInKeyWindow owner:self userInfo:nil];
    [self addTrackingArea:self.tracking];
    [self dpLibraryUpdatePointerHover];
}
- (void)dpLibraryUpdatePointerHover {
    BOOL selected=[self.superview isKindOfClass:NSTableRowView.class] && [(NSTableRowView *)self.superview isSelected];
    self.rowHovered=selected || DPLibraryPointerInside(self);
    for(NSButton *button in self.actions) button.hidden=!self.rowHovered;
}
- (void)mouseEntered:(NSEvent *)event { [self dpLibraryUpdatePointerHover]; }
- (void)mouseExited:(NSEvent *)event { [self dpLibraryUpdatePointerHover]; }
- (void)layout {
    [super layout];
    for (NSUInteger i=0;i<self.actions.count;i++) self.actions[i].frame=NSMakeRect(MAX(60,NSWidth(self.bounds)-38-(self.actions.count-1-i)*34),17,30,30);
    CGFloat width=MAX(20,NSWidth(self.bounds)-72-self.actions.count*34);
    self.textField.frame=NSMakeRect(60,32,width,20);
    for (NSView *v in self.subviews) if ([v.identifier isEqual:@"detail"]) v.frame=NSMakeRect(60,12,width,18);
}
@end
void DPLibraryConfigureRowActions(NSTableCellView *cell,DPLibraryController *owner,DPLibraryFile *file) {
    DPLibraryActionCell *row=(id)cell;
    NSMutableArray *buttons=NSMutableArray.new;
    NSArray *symbols=file.archived ? @[@"eye.slash",@"arrow.uturn.backward"] : @[@"ellipsis"];
    NSArray *actions=file.archived ? @[@"hideArchive:",@"reopenArchive:"] : @[@"showDownloadMenu:"];
    NSArray *labels=file.archived ? @[owner.showHidden ? @"Restore to Library" : @"Hide from Library",@"Open in New Tab"] : @[@"Download actions"];
    BOOL reuse=row.actions.count==symbols.count;
    if(!reuse) for(NSButton *button in row.actions) [button removeFromSuperview];
    for (NSUInteger i=0;i<symbols.count;i++) {
        NSButton *button=reuse ? row.actions[i] :DPLibraryMakeButton(@"",symbols[i],owner,NSSelectorFromString(actions[i]));
        if (file.archived && !reuse) {
            NSButton *archive=[NSClassFromString(@"DPLibraryArchiveActionButton") buttonWithTitle:@"" target:owner action:NSSelectorFromString(actions[i])];
            archive.bordered=NO; archive.image=button.image; archive.imagePosition=NSImageOnly; archive.contentTintColor=NSColor.labelColor;
            button=archive;
        }
        button.accessibilityLabel=labels[i]; button.accessibilityHelp=labels[i]; button.toolTip=file.archived ? nil : labels[i]; button.identifier=file.identifier;
        button.hidden=!row.rowHovered; if(button.superview!=row) [row addSubview:button]; [buttons addObject:button];
    }
    row.actions=buttons; row.needsLayout=YES;
}
@implementation DPLibraryController (RowActions)
- (BOOL)selectActionRow:(NSButton *)sender {
    NSInteger row=[self.table rowForView:sender]; if(row<0 || row>=(NSInteger)self.rows.count) return NO;
    [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO]; return YES;
}
- (void)showDownloadMenu:(NSButton *)sender {
    if (![self selectActionRow:sender]) return;
    [[self fileMenu] popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,NSHeight(sender.bounds)) inView:sender];
}
- (void)reopenArchive:(NSButton *)sender { if ([self selectActionRow:sender]) [self openSelection:sender]; }
- (void)hideArchive:(NSButton *)sender {
    if (![self selectActionRow:sender]) return;
    if(self.showHidden) [self restoreSelection:sender]; else [self hideSelection:sender];
}
@end

void DPLibrarySetRowHovered(NSView *row,BOOL hovered) {
    for (NSView *v in row.subviews) if ([v isKindOfClass:DPLibraryActionCell.class]) {
        DPLibraryActionCell *cell=(id)v; cell.rowHovered=hovered;
        for(NSButton *button in cell.actions) button.hidden=!hovered;
    }
}
