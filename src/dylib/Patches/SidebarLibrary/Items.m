#import "Library.h"
@implementation DPLibraryController (Items)
- (void)displayFiles:(NSArray<DPLibraryFile *> *)files media:(BOOL)media {
    BOOL animate=self.animateRemoval; self.animateRemoval=NO; NSMutableDictionary *positions=NSMutableDictionary.new;
    if(animate) {
        if(media) for(NSIndexPath *path in self.collection.indexPathsForVisibleItems) {
            if((NSUInteger)path.item<self.mediaFiles.count) { NSView *view=[self.collection itemAtIndexPath:path].view; if(view) positions[self.mediaFiles[path.item].key]=[NSValue valueWithRect:view.frame]; }
        } else for(NSUInteger i=0;i<self.rows.count;i++) if([self.rows[i] isKindOfClass:DPLibraryFile.class]) positions[[self.rows[i] key]]=[NSValue valueWithRect:[self.table rectOfRow:i]];
    }
    NSMutableArray *state = [NSMutableArray arrayWithObjects:self.section,self.context ?: @"",[NSCalendar.currentCalendar startOfDayForDate:NSDate.date],nil];
    for (DPLibraryFile *file in files) {
        file.missing = !file.archived && file.state == 2 && ![NSFileManager.defaultManager fileExistsAtPath:file.path];
        long long percent = file.state == 1 && file.total > 0 ? 100.0*file.completed/file.total : 0;
        [state addObject:@[file.key ?: @"",file.path ?: @"",file.title ?: @"",file.source ?: @"",@(file.state),@(file.missing),@(percent),@(file.completed),@(file.total),@(file.paused),@(file.remaining),file.date ?: NSDate.distantPast]];
    }
    NSArray *selected = [self.selectedFiles valueForKey:@"key"];
    if ([self.listingState isEqual:state]) return;
    BOOL hadListing=self.listingState!=nil;
    self.listingState = state;
    self.files = files;
    if (media) { self.mediaFiles = files; [self.collection reloadData]; }
    else {
        NSArray *rows=DPLibraryDateSections(files,NSDate.date);
        NSMutableArray *before=NSMutableArray.new,*after=NSMutableArray.new;
        for(id row in self.rows) [before addObject:[row isKindOfClass:DPLibraryFile.class] ? [row key] : row];
        for(id row in rows) [after addObject:[row isKindOfClass:DPLibraryFile.class] ? [row key] : row];
        self.rows=rows;
        if(hadListing && [before isEqual:after]) {
            // Progress changes never recycle completed rows or reset their images.
            NSRange visible=[self.table rowsInRect:self.table.visibleRect];
            for(NSUInteger i=visible.location;i<NSMaxRange(visible) && i<rows.count;i++) if([rows[i] isKindOfClass:DPLibraryFile.class]) {
                NSTableCellView *cell=[self.table viewAtColumn:0 row:i makeIfNecessary:NO];
                if(cell) [self updateFileCell:cell file:rows[i] loadImage:NO];
            }
        } else [self.table reloadData];
    }
    if(animate) {
        NSView *container=media ? self.collection : self.table; [container layoutSubtreeIfNeeded];
        NSArray *records=media ? self.mediaFiles : self.rows;
        for(NSUInteger i=0;i<records.count;i++) {
            if(![records[i] isKindOfClass:DPLibraryFile.class]) continue;
            NSValue *before=positions[[records[i] key]]; if(!before) continue;
            NSView *view=media ? [self.collection itemAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]].view : [self.table rowViewAtRow:i makeIfNecessary:NO];
            if(!view || view.hiddenOrHasHiddenAncestor || NSIsEmptyRect(view.visibleRect)) continue;
            NSRect after=media ? view.frame : [self.table rectOfRow:i]; CGFloat dx=NSMinX(before.rectValue)-NSMinX(after),dy=NSMinY(before.rectValue)-NSMinY(after);
            if(fabs(dx)<.5 && fabs(dy)<.5) continue;
            view.wantsLayer=YES; CAAnimationGroup *move=CAAnimationGroup.animation; NSMutableArray *axes=NSMutableArray.new;
            for(NSUInteger axis=0;axis<2;axis++) { CABasicAnimation *part=[CABasicAnimation animationWithKeyPath:axis ? @"transform.translation.y" : @"transform.translation.x"]; part.fromValue=@(axis ? dy : dx); part.toValue=@0; [axes addObject:part]; }
            move.animations=axes; move.duration=.18; move.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]; [view.layer addAnimation:move forKey:@"libraryReflow"];
        }
    }
    NSSet *identifiers = [NSSet setWithArray:selected ?: @[]];
    NSMutableIndexSet *indices = [NSMutableIndexSet new];
    NSArray *source = media ? files : self.rows;
    [source enumerateObjectsUsingBlock:^(id record,NSUInteger index,BOOL *stop) {
        if ([record isKindOfClass:DPLibraryFile.class] && [identifiers containsObject:[record key]]) [indices addIndex:index];
    }];
    if (media) self.collection.selectionIndexes = indices;
    else [self.table selectRowIndexes:indices byExtendingSelection:NO];
}
@end
