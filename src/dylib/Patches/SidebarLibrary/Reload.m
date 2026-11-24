#import "Library.h"
@implementation DPLibraryController (Reload)
- (void)reload {
    if(DPLibraryReloadCustomSection(self)) return;
    if (self.removing) { self.listingState=nil; return; }
    if (self.dragging) { self.reloadAfterDrag = YES; return; }
    if (!self.context) {
        NSString *resolved = DPLibraryContextForWindow(self.window);
        if (resolved) { self.context = resolved; self.listingState = nil; }
    }
    BOOL media = [self.section isEqual:@"Media"];
    BOOL archive = [self.section isEqual:@"Archived Tabs"];
    NSSet *hidden=DPLibraryHiddenIDs(self.context,archive);
    NSArray *files;
    if (archive) {
        NSString *query = self.search.stringValue;
        NSDate *today = [NSCalendar.currentCalendar startOfDayForDate:NSDate.date];
        NSInteger days = self.filterIndex == 1 ? 0 : self.filterIndex == 2 ? -7 : -30;
        NSDate *cutoff = self.filterIndex > 0 ? [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:days toDate:today options:0] : nil;
        files = [self.archive filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DPLibraryFile *file,NSDictionary *bindings) {
            if ([hidden containsObject:file.identifier] != self.showHidden) return NO;
            if (cutoff && [file.date compare:cutoff] == NSOrderedAscending) return NO;
            return !query.length || [file.title rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound ||
                [file.source rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }]] ?: @[];
    } else {
        NSArray *source=media ? (self.context ? DPLibrarySharedMediaFiles(self.showHidden) : @[]) : self.showHidden ? [DPLibraryAllFiles(self.context) filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DPLibraryFile *file,NSDictionary *bindings) { return [hidden containsObject:file.identifier]; }]] : DPLibraryFiles(self.context);
        files = DPLibraryFiltered(source,self.search.stringValue,self.filterIndex,media);
    }
    // Download bytes change row content, not the surrounding chrome geometry.
    self.table.accessibilityLabel = self.section;
    self.search.placeholderString = [@"Search " stringByAppendingString:self.showHidden ? [@"Hidden " stringByAppendingString:self.section] : self.section];
    self.scroll.hidden = media; self.mediaScroll.hidden = !media; self.filterChrome.hidden = media;
    [(NSPopUpButtonCell *)self.filter.cell setTitle:@"Filter"];
    self.filter.accessibilityLabel = archive ? @"Filter archived tabs" : @"Filter downloads";
    [self displayFiles:files media:media];
#ifdef DPLIBRARY_DIAGNOSTICS
    NSDictionary *status = @{@"context":self.context ?: @"",@"space":self.spaceID ?: @"",@"activeSpace":DPLibraryActiveSpace(self.window) ?: @"",@"section":self.section,@"inputCount":@(files.count),@"displayCount":@(self.files.count),@"mediaCount":@(self.mediaFiles.count),@"dragging":@(self.dragging)};
    [[NSJSONSerialization dataWithJSONObject:status options:0 error:nil] writeToFile:@"/tmp/sidebar-library-ui-state.json" atomically:YES];
#endif
    self.empty.hidden = self.files.count > 0;
    [self layout];
    self.empty.stringValue = !self.context ? @"Loading Library…" : self.search.stringValue.length ? @"No matching files" :
        (self.showHidden ? @"No hidden items. Hidden items stay on your Mac." : archive ? @"No archived tabs in this profile." : (media ? @"Downloaded images and videos from all profiles appear here." : @"Downloads from this profile appear here."));
}
- (void)controlTextDidChange:(NSNotification *)note { if (note.object == self.search) [self reload]; }
- (void)controlTextDidBeginEditing:(NSNotification *)note { self.searchChrome.needsDisplay = YES; }
- (void)controlTextDidEndEditing:(NSNotification *)note { self.searchChrome.needsDisplay = YES; }
@end
