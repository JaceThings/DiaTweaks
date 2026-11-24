#import "Library.h"
#import <objc/runtime.h>
void DPLibraryUpdateDownloadProgress(NSTableCellView *,DPLibraryFile *);
static char DPRowImageKey;
BOOL DPLibraryIsEaselFile(DPLibraryFile *file);
void DPLibrarySetRowHovered(NSView *,BOOL);
void DPLibraryConfigureRowActions(NSTableCellView *,DPLibraryController *,DPLibraryFile *);
BOOL DPLibraryOpenArchivedURL(NSWindow *window,NSURL *url);
@interface DPLibraryFileIcon : NSImageView @end
@implementation DPLibraryFileIcon
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end
@implementation DPLibraryController (FileRows)
- (void)tableView:(NSTableView *)table draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)point forRowIndexes:(NSIndexSet *)rows { self.dragging = YES; }
- (void)tableView:(NSTableView *)table draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)point operation:(NSDragOperation)operation {
    self.dragging = NO; self.reloadAfterDrag = NO; self.listingState = nil; [self reload];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.rows.count; }
- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.rows.count) return [NSView new];
    id record = self.rows[row];
    if ([record isKindOfClass:NSString.class]) {
        NSTextField *label = [NSTextField labelWithString:record]; label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
        label.textColor = NSColor.secondaryLabelColor; return label;
    }
    DPLibraryFile *file = record;
    NSTableCellView *cell = [table makeViewWithIdentifier:@"file" owner:self];
    if (!cell) {
        cell = [[NSClassFromString(@"DPLibraryActionCell") alloc] initWithFrame:NSMakeRect(0,0,350,64)]; cell.identifier = @"file";
        NSImageView *icon = [[DPLibraryFileIcon alloc] initWithFrame:NSMakeRect(12,14,36,36)];
        icon.imageScaling = NSImageScaleProportionallyUpOrDown;
        [cell addSubview:icon]; cell.imageView = icon;
        NSTextField *title = [NSTextField labelWithString:@""]; title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        title.frame = NSMakeRect(60,32,260,20); title.autoresizingMask = NSViewWidthSizable;
        title.lineBreakMode = NSLineBreakByTruncatingMiddle; [cell addSubview:title]; cell.textField = title;
        NSTextField *detail = [NSTextField labelWithString:@""]; detail.identifier = @"detail";
        detail.font = [NSFont systemFontOfSize:11]; detail.textColor = NSColor.secondaryLabelColor;
        detail.lineBreakMode = NSLineBreakByTruncatingMiddle;
        detail.frame = NSMakeRect(60,12,260,18); detail.autoresizingMask = NSViewWidthSizable;
        [cell addSubview:detail];
    }
    [self updateFileCell:cell file:file loadImage:YES];
    return cell;
}
- (void)updateFileCell:(NSTableCellView *)cell file:(DPLibraryFile *)file loadImage:(BOOL)loadImage {
    DPLibraryConfigureRowActions(cell,self,file);
    NSString *name = (file.archived ? file.title : file.path.lastPathComponent) ?: @"Download";
    cell.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:name attributes:@{
        NSFontAttributeName:cell.textField.font,
        NSForegroundColorAttributeName:file.missing ? NSColor.secondaryLabelColor : NSColor.labelColor,
        NSStrikethroughStyleAttributeName:@(file.missing ? NSUnderlineStyleSingle : NSUnderlineStyleNone)}];
    NSArray *key=@[self.context ?: @"",file.key ?: @"",file.path ?: @"",file.source ?: @"",@(file.state),@(file.missing)];
    BOOL changed=![objc_getAssociatedObject(cell,&DPRowImageKey) isEqual:key];
    cell.objectValue = file.identifier;
    if(changed) {
        objc_setAssociatedObject(cell,&DPRowImageKey,key,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        cell.imageView.contentTintColor = NSColor.secondaryLabelColor;
        cell.imageView.image = file.archived ? [NSImage imageWithSystemSymbolName:DPLibraryIsEaselFile(file) ? @"pencil.and.outline" : @"globe" accessibilityDescription:nil] : file.missing ? [NSImage imageWithSystemSymbolName:@"doc" accessibilityDescription:@"File unavailable"] : file.state==1 ? nil : [NSWorkspace.sharedWorkspace iconForFile:file.path];
    }
    DPLibraryUpdateDownloadProgress(cell,file);
    if(changed || loadImage) {
        __weak NSTableCellView *weakCell=cell;
        void (^imageReady)(NSImage *)=^(NSImage *image) {
            if(image && [objc_getAssociatedObject(weakCell,&DPRowImageKey) isEqual:key]) weakCell.imageView.image=image;
        };
        if(file.archived) DPLibraryFavicon(self.context,file.source,imageReady);
        else if(file.state==2 && !file.missing && DPLibraryIsMedia(file)) DPLibraryThumbnail([NSURL fileURLWithPath:file.path],imageReady);
    }
    NSString *status = DPLibraryFileDetail(file);
    for (NSView *view in cell.subviews) if ([view.identifier isEqual:@"detail"]) [(NSTextField *)view setStringValue:status];
    cell.toolTip = file.archived ? file.source : file.path; cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",cell.textField.stringValue,status];
}
- (id<NSPasteboardWriting>)tableView:(NSTableView *)table pasteboardWriterForRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.rows.count || ![self.rows[row] isKindOfClass:DPLibraryFile.class]) return nil;
    DPLibraryFile *file = self.rows[row];
    if (file.archived) { NSURL *url = [NSURL URLWithString:file.source]; return DPLibraryCanOpenArchivedURL(url) ? url : nil; }
    return file.state == 2 && [NSFileManager.defaultManager fileExistsAtPath:file.path] ? [NSURL fileURLWithPath:file.path] : nil;
}
- (BOOL)tableView:(NSTableView *)table isGroupRow:(NSInteger)row { return row >= 0 && row < (NSInteger)self.rows.count && [self.rows[row] isKindOfClass:NSString.class]; }
- (BOOL)tableView:(NSTableView *)table shouldSelectRow:(NSInteger)row { return row >= 0 && row < (NSInteger)self.rows.count && [self.rows[row] isKindOfClass:DPLibraryFile.class]; }
- (CGFloat)tableView:(NSTableView *)table heightOfRow:(NSInteger)row { return row >= 0 && row < (NSInteger)self.rows.count && [self.rows[row] isKindOfClass:NSString.class] ? 28 : 64; }
- (void)openSelection:(id)sender {
    for (DPLibraryFile *file in [self selectedFiles]) {
        if (file.archived) { if (DPLibraryOpenArchivedURL(self.window,[NSURL URLWithString:file.source])) [self close]; else NSBeep(); continue; }
        if (file.state == 2 && [NSFileManager.defaultManager fileExistsAtPath:file.path])
            [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:file.path]];
    }
}
- (void)revealSelection:(id)sender {
    NSArray *urls = [self selectedFileURLs];
    if (urls.count) [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:urls];
}
@end

@interface DPLibraryRowView : NSTableRowView
@property NSTrackingArea *hoverTracking;
@property BOOL hovered;
@end
@implementation DPLibraryRowView
- (void)setSelected:(BOOL)selected { [super setSelected:selected]; DPLibrarySetRowHovered(self,selected || self.hovered); }
- (NSBackgroundStyle)interiorBackgroundStyle { return NSBackgroundStyleNormal; }
- (void)drawSelectionInRect:(NSRect)dirty {
    [[NSColor.labelColor colorWithAlphaComponent:.11] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,4,2) xRadius:12 yRadius:12] fill];
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if (self.hoverTracking) [self removeTrackingArea:self.hoverTracking];
    self.hoverTracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:self.hoverTracking];
    [self dpLibraryUpdatePointerHover];
}
- (void)dpLibraryUpdatePointerHover {
    BOOL inside=DPLibraryPointerInside(self);
    if(self.hovered!=inside) { self.hovered=inside; self.needsDisplay=YES; }
    DPLibrarySetRowHovered(self,self.selected || inside);
}
- (void)mouseEntered:(NSEvent *)event { [self dpLibraryUpdatePointerHover]; }
- (void)mouseExited:(NSEvent *)event { [self dpLibraryUpdatePointerHover]; }
- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    if (self.hovered && !self.selected) {
        [[NSColor.labelColor colorWithAlphaComponent:.075] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,4,2) xRadius:12 yRadius:12] fill];
    }
}
@end
@implementation DPLibraryController (RowAppearance)
- (NSTableRowView *)tableView:(NSTableView *)table rowViewForRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.rows.count || ![self.rows[row] isKindOfClass:DPLibraryFile.class]) return nil;
    return [DPLibraryRowView new];
}
@end
