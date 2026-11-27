#import "StdPatch/Hide.h"

extern DPPatch DPHideSetupSuggestions;

static char DPHiddenRowsKey, DPRowCountKey, DPNotingKey, DPHidByUsKey, DPDiaHiddenKey, DPRowKey;

static NSSet<NSString *> *DPOnboardingTitles(void) {
    static NSSet<NSString *> *titles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        titles = [NSSet setWithArray:@[ @"Upgrade Chat", @"Import from another browser", @"Import passwords", @"Sign in to Google Calendar" ]];
    });
    return titles;
}

static NSString *DPTitleIn(NSView *cell) {
    NSView *title = DPFindView(cell, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaSuggestionTitle); });
    NSTextField *label = (NSTextField *)DPFindView(title, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSTextField.class] && ((NSTextField *)view).stringValue.length > 0;
    });
    return [label.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static BOOL DPIsSetupSuggestion(NSView *cell) {
    if (!DPIsKind(cell, DPDiaSuggestionCell)) return NO;
    NSString *title = DPTitleIn(cell);
    return title.length > 0 && [DPOnboardingTitles() containsObject:title];
}

// Collapsed rows mapped weakly to their cell, so a row Dia reuses or replaces is never left at zero height.
static NSMapTable<NSNumber *, NSView *> *DPHiddenRows(NSTableView *table) {
    NSMapTable<NSNumber *, NSView *> *rows = DPGet(table, &DPHiddenRowsKey);
    if (rows && [DPGet(table, &DPRowCountKey) integerValue] == table.numberOfRows) return rows;
    rows = [NSMapTable strongToWeakObjectsMapTable];
    DPSet(table, &DPHiddenRowsKey, rows);
    DPSet(table, &DPRowCountKey, @(table.numberOfRows));
    return rows;
}

static void DPForgetHiddenRows(NSTableView *table) {
    DPSet(table, &DPHiddenRowsKey, nil);
    DPSet(table, &DPRowCountKey, nil);
}

static void DPNoteRows(NSTableView *table) {
    if ([DPGet(table, &DPNotingKey) boolValue]) return;
    DPSet(table, &DPNotingKey, @YES);
    dispatch_async(dispatch_get_main_queue(), ^{
        DPSet(table, &DPNotingKey, nil);
        NSInteger count = table.numberOfRows;
        if (count > 0) [table noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, count)]];
    });
}

static BOOL DPIsCollapsedRow(NSTableView *table, NSInteger row) {
    NSMapTable<NSNumber *, NSView *> *rows = DPHiddenRows(table);
    NSView *cell = [rows objectForKey:@(row)];
    // AppKit throws if heightOfRow: asks for a row view; rowForView: only walks existing views.
    if (!cell || ![cell isDescendantOf:table] || [table rowForView:cell] != row || !DPIsSetupSuggestion(cell)) {
        [rows removeObjectForKey:@(row)];
        return NO;
    }
    return YES;
}

static NSTableView *DPTableOf(NSView *cell) {
    for (NSView *up = cell.superview; up; up = up.superview)
        if ([up isKindOfClass:NSTableView.class]) return (NSTableView *)up;
    return nil;
}

static void DPRestoreHidden(NSView *cell) {
    if (![DPGet(cell, &DPHidByUsKey) boolValue]) return;
    BOOL diaHidden = [DPGet(cell, &DPDiaHiddenKey) boolValue];
    DPSet(cell, &DPHidByUsKey, nil);
    DPSet(cell, &DPDiaHiddenKey, nil);
    cell.hidden = diaHidden;
}

static CGFloat DPSuggestions_heightOfRow(NSView *self, SEL _cmd, NSTableView *table, NSInteger row) {
    CGFloat height = DPCallOriginal(DPSuggestions_heightOfRow, self, table, row);
    // AppKit throws NSInternalInconsistencyException if heightOfRow: returns <= 0.
    if (DPHideSetupSuggestions.on && DPIsCollapsedRow(table, row)) return 0.001;
    return height;
}

static BOOL DPSuggestions_shouldSelectRow(NSView *self, SEL _cmd, NSTableView *table, NSInteger row) {
    if (DPHideSetupSuggestions.on && DPIsCollapsedRow(table, row)) return NO;
    return DPCallOriginal(DPSuggestions_shouldSelectRow, self, table, row);
}

static void DPSuggestionCell_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSuggestionCell_layout, self);
    BOOL hide = DPHideSetupSuggestions.on && DPIsSetupSuggestion(self);
    if (hide) {
        if (![DPGet(self, &DPHidByUsKey) boolValue]) {
            DPSet(self, &DPDiaHiddenKey, @(self.hidden));
            DPSet(self, &DPHidByUsKey, @YES);
        }
        if (!self.hidden) self.hidden = YES;
    } else DPRestoreHidden(self);
    if (!hide && !DPHideSetupSuggestions.on) return;
    NSTableView *table = DPTableOf(self);
    if (!table) return;
    if (!hide && !DPGet(table, &DPHiddenRowsKey)) return;
    NSInteger row = [table rowForView:self];
    if (row < 0) return;
    NSMapTable<NSNumber *, NSView *> *rows = DPHiddenRows(table);
    NSNumber *prevRow = DPGet(self, &DPRowKey);
    BOOL note = NO;
    if (prevRow && prevRow.integerValue != row && [rows objectForKey:prevRow] == self) {
        [rows removeObjectForKey:prevRow];
        note = YES;
    }
    if (hide) {
        if ([rows objectForKey:@(row)] != self) {
            [rows setObject:self forKey:@(row)];
            note = YES;
        }
        DPSet(self, &DPRowKey, @(row));
    } else {
        DPSet(self, &DPRowKey, nil);
        if ([rows objectForKey:@(row)]) {
            [rows removeObjectForKey:@(row)];
            note = YES;
        }
    }
    if (note) DPNoteRows(table);
}

static void DPSuggestionCell_prepareForReuse(NSView *self, SEL _cmd) {
    DPRestoreHidden(self);
    NSNumber *prevRow = DPGet(self, &DPRowKey);
    DPSet(self, &DPRowKey, nil);
    if (prevRow) {
        NSTableView *table = DPTableOf(self);
        NSMapTable<NSNumber *, NSView *> *rows = table ? DPGet(table, &DPHiddenRowsKey) : nil;
        if (rows && [rows objectForKey:prevRow] == self) {
            [rows removeObjectForKey:prevRow];
            DPNoteRows(table);
        }
    }
    DPCallOriginal(DPSuggestionCell_prepareForReuse, self);
}

static void DPSuggestionsTable_reloadData(NSTableView *self, SEL _cmd) {
    DPForgetHiddenRows(self);
    DPCallOriginal(DPSuggestionsTable_reloadData, self);
}

static void DPSuggestionsTable_reloadRows(NSTableView *self, SEL _cmd, NSIndexSet *rows, NSIndexSet *columns) {
    DPForgetHiddenRows(self);
    DPCallOriginal(DPSuggestionsTable_reloadRows, self, rows, columns);
}

static void DPInstallHideSetupSuggestions(void) {
    DPHook(DPDiaCommandBarSuggestions, @selector(tableView:heightOfRow:), (IMP)DPSuggestions_heightOfRow);
    DPHook(DPDiaCommandBarSuggestions, @selector(tableView:shouldSelectRow:), (IMP)DPSuggestions_shouldSelectRow);
    DPHook(DPDiaSuggestionCell, @selector(layout), (IMP)DPSuggestionCell_layout);
    DPHook(DPDiaSuggestionCell, @selector(prepareForReuse), (IMP)DPSuggestionCell_prepareForReuse);
    if (objc_getClass(DPDiaSuggestionsTable)) {
        DPHook(DPDiaSuggestionsTable, @selector(reloadData), (IMP)DPSuggestionsTable_reloadData);
        DPHook(DPDiaSuggestionsTable, @selector(reloadDataForRowIndexes:columnIndexes:), (IMP)DPSuggestionsTable_reloadRows);
    }
}

static void DPApplyHideSetupSuggestions(DPPatch *patch) {
    for (NSView *view in DPFindViews(DPDiaCommandBarSuggestions)) {
        NSTableView *table = (NSTableView *)DPFindView(view, ^BOOL(NSView *sub) { return [sub isKindOfClass:NSTableView.class]; });
        if (!table) continue;
        DPForgetHiddenRows(table);
        if (table.numberOfRows > 0) [table noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, table.numberOfRows)]];
        [table reloadData];
    }
}

DP_PATCH(DPHideSetupSuggestions) {
    .key = @"hideSetupSuggestions",
    .order = 91,
    .section = @"Command Bar",
    .title = @"Hide Setup Suggestions",
    .detail = @"Hide the setup rows in the command bar, like “Upgrade Chat” and “Import from another browser”. Searches, links and open tabs still show.",
    .symbol = @"text.badge.xmark",
    .tint = @"systemOrangeColor",
    .classes = DPClasses(DPDiaCommandBarSuggestions, DPDiaSuggestionCell, DPDiaSuggestionTitle, DPDiaSuggestionsTable),
    .install = DPInstallHideSetupSuggestions,
    .apply = DPApplyHideSetupSuggestions,
};
