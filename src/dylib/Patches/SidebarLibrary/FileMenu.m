#import "Library.h"
#import <Quartz/Quartz.h>
@implementation DPLibraryController (FileMenu)
- (NSArray<DPLibraryFile *> *)selectedFiles {
    BOOL media = [self.section isEqual:@"Media"];
    NSIndexSet *selected = media ? self.collection.selectionIndexes : self.table.selectedRowIndexes;
    NSArray *source = media ? self.mediaFiles : self.rows;
    NSMutableArray *files = [NSMutableArray new];
    [selected enumerateIndexesUsingBlock:^(NSUInteger index,BOOL *stop) {
        if (index < source.count && [source[index] isKindOfClass:DPLibraryFile.class]) [files addObject:source[index]];
    }];
    return files;
}
- (NSArray<NSURL *> *)selectedFileURLs {
    NSMutableArray *urls = [NSMutableArray new];
    for (DPLibraryFile *file in [self selectedFiles])
        if (!file.archived && file.state == 2 && [NSFileManager.defaultManager fileExistsAtPath:file.path]) [urls addObject:[NSURL fileURLWithPath:file.path]];
    return urls;
}
- (void)copy:(id)sender {
    NSArray *urls = [self selectedFileURLs]; if (!urls.count) return;
    [NSPasteboard.generalPasteboard clearContents]; [NSPasteboard.generalPasteboard writeObjects:urls];
}
- (void)shareSelection:(id)sender {
    NSArray *urls = [self selectedFileURLs]; if (!urls.count) return;
    self.sharingPicker = [[NSSharingServicePicker alloc] initWithItems:urls];
    NSRect anchor = self.scroll.frame;
    if ([self.section isEqual:@"Media"] && self.collection.selectionIndexPaths.count) {
        NSIndexPath *path = self.collection.selectionIndexPaths.anyObject;
        anchor = [self.view convertRect:[self.collection layoutAttributesForItemAtIndexPath:path].frame fromView:self.collection];
    } else if (self.table.selectedRow >= 0) anchor = [self.view convertRect:[self.table rectOfRow:self.table.selectedRow] fromView:self.table];
    [self.sharingPicker showRelativeToRect:NSIntersectionRect(anchor,self.view.bounds) ofView:self.view preferredEdge:NSMaxXEdge];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.menu == self.filter.menu) return YES;
    if (self.removing) return NO;
    if (item.action == @selector(hideSelection:) || item.action == @selector(restoreSelection:)) return self.selectedFiles.count > 0;
    if ([self.section isEqual:@"Archived Tabs"]) return self.selectedFiles.count > 0;
    return self.selectedFileURLs.count > 0;
}
- (void)hideSelection:(id)sender {
    if (self.removing || !self.selectedFiles.count) return;
    NSArray *files=self.selectedFiles; NSString *profile=self.context; NSMutableArray *views=NSMutableArray.new;
    if ([self.section isEqual:@"Media"]) {
        for (NSIndexPath *path in self.collection.selectionIndexPaths) { NSView *v=[self.collection itemAtIndexPath:path].view; if (v) [views addObject:v]; }
    } else [self.table.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger index,BOOL *stop) { NSView *v=[self.table rowViewAtRow:index makeIfNecessary:NO]; if(v) [views addObject:v]; }];
    self.removing=YES;
    DPLibraryDissolve(views,^{ DPLibrarySetHidden(profile,files,YES); self.removing=NO; self.animateRemoval=DPSidebarLibraryDust.on && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion; if ([self.context isEqual:profile]) { self.listingState=nil; [self reload]; } });
}
- (NSMenu *)fileMenu {
    NSMenu *menu = [NSMenu new];
    if ([self.section isEqual:@"Archived Tabs"]) {
        NSArray *titles=@[@"Open in New Tab",self.showHidden ? @"Restore to Library" : @"Hide from Library"];
        NSArray *actions=@[@"openSelection:",self.showHidden ? @"restoreSelection:" : @"hideSelection:"];
        for (NSUInteger i=0;i<titles.count;i++) { NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:titles[i] action:NSSelectorFromString(actions[i]) keyEquivalent:@""]; item.target=self; [menu addItem:item]; }
        return menu;
    }
    BOOL media=[self.section isEqual:@"Media"];
    NSArray *titles = media ? @[@"Open",@"Copy Image",@"Quick Look",@"Show in Finder",@"Share…",@"",self.showHidden ? @"Restore to Library" : @"Hide from Library"] :
        @[@"Open",@"Copy",@"Quick Look",@"Show in Finder",@"Share…",@"",self.showHidden ? @"Restore to Library" : @"Hide from Library",@"Move to Trash"];
    NSArray *actions = media ? @[@"openSelection:",@"copyImage:",@"quickLook:",@"revealSelection:",@"shareSelection:",@"",self.showHidden ? @"restoreSelection:" : @"hideSelection:"] :
        @[@"openSelection:",@"copy:",@"quickLook:",@"revealSelection:",@"shareSelection:",@"",self.showHidden ? @"restoreSelection:" : @"hideSelection:",@"trashSelection:"];
    for (NSUInteger i=0;i<titles.count;i++) {
        if (![titles[i] length]) { [menu addItem:NSMenuItem.separatorItem]; continue; }
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:titles[i] action:NSSelectorFromString(actions[i]) keyEquivalent:@""];
        item.target = self;

        [menu addItem:item];
    }
    return menu;
}
@end
#define DPLibraryPreviewResponderMethods \
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel { return self.window && !self.hiddenOrHasHiddenAncestor && [(DPLibraryController *)self.delegate previewSource] != nil; } \
- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel { panel.dataSource = [(DPLibraryController *)self.delegate previewSource]; } \
- (void)endPreviewPanelControl:(QLPreviewPanel *)panel { panel.dataSource = nil; }
@interface DPLibraryTable : NSTableView @end
@implementation DPLibraryTable
DPLibraryPreviewResponderMethods
- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 49) DPLibraryTogglePreview((id)self.delegate,self);
    else if (event.keyCode == 36) [(DPLibraryController *)self.delegate openSelection:self];
    else [super keyDown:event];
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSInteger row = [self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if (row < 0 || ![(DPLibraryController *)self.delegate tableView:self shouldSelectRow:row]) return nil;
    if (![self.selectedRowIndexes containsIndex:row]) [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    return [(DPLibraryController *)self.delegate fileMenu];
}
- (void)copy:(id)sender { [(DPLibraryController *)self.delegate copy:sender]; }
@end
@interface DPLibraryCollection : NSCollectionView @end
@implementation DPLibraryCollection
DPLibraryPreviewResponderMethods
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSIndexPath *path = [self indexPathForItemAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if (!path) return nil;
    if (![self.selectionIndexPaths containsObject:path]) self.selectionIndexPaths = [NSSet setWithObject:path];
    return [(DPLibraryController *)self.delegate fileMenu];
}
- (void)copy:(id)sender { [(DPLibraryController *)self.delegate copy:sender]; }
- (void)mouseDown:(NSEvent *)event { [super mouseDown:event]; if (event.clickCount == 2) [(DPLibraryController *)self.delegate openSelection:self]; }
- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 49) DPLibraryTogglePreview((id)self.delegate,self);
    else if (event.keyCode == 36) [(DPLibraryController *)self.delegate openSelection:self];
    else [super keyDown:event];
}
@end
