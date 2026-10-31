#import "Settings.h"

static NSUserInterfaceItemIdentifier const DPPatchesCellIdentifier = @"DiaPatchesCell";
static char DPSettingsKey, DPSearchItemKey;

// Patches is the extra last row of Dia's Settings sidebar. Dia never sees its index: Dia's cell lookup traps past the end of its items.
static BOOL DPIsPatchesRow(NSTableView *table, NSInteger row) {
    return row >= 0 && row == table.numberOfRows - 1;
}

@interface DPSettings : NSObject
@property (nonatomic, weak) NSTableView *table;
@property (nonatomic, weak) NSTextField *title;
@property (nonatomic, copy) NSString *originalTitle;
@property (nonatomic, strong) DPPaneView *pane;
@end

@implementation DPSettings

+ (DPSettings *)forTable:(NSTableView *)table {
    DPSettings *settings = DPGet(table, &DPSettingsKey);
    if (settings) return settings;
    settings = [DPSettings new];
    settings.table = table;
    DPSet(table, &DPSettingsKey, settings);
    return settings;
}

- (void)showPane {
    NSWindow *window = self.table.window;
    NSView *detail = ((NSSplitViewController *)window.contentViewController).splitViewItems.lastObject.viewController.view;
    if (self.pane.superview || !detail) return;
    self.pane = self.pane ?: [[DPPaneView alloc] initWithFrame:detail.bounds];
    self.pane.frame = detail.bounds;
    self.pane.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [detail addSubview:self.pane positioned:NSWindowAbove relativeTo:nil];
    [self.pane refresh];

    NSToolbar *toolbar = window.toolbar;
    DPSet(toolbar, &DPSearchItemKey, self.pane.searchItem);
    [toolbar insertItemWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier atIndex:toolbar.items.count];
    [toolbar insertItemWithItemIdentifier:DPSearchItemIdentifier atIndex:toolbar.items.count];

    for (NSToolbarItem *item in toolbar.items)
        if ([item.itemIdentifier isEqualToString:@"PreferencesPaneTitle"])
            self.title = (NSTextField *)DPFindView(item.view, ^BOOL(NSView *v) { return [v isKindOfClass:NSTextField.class]; });
    self.originalTitle = self.title.stringValue;
    self.title.stringValue = @"Patches";
}

- (void)hidePane {
    if (!self.pane.superview) return;
    [self.pane removeFromSuperview];
    NSToolbar *toolbar = self.table.window.toolbar;
    NSUInteger index = [toolbar.items indexOfObject:self.pane.searchItem];
    if (index != NSNotFound) {
        [toolbar removeItemAtIndex:index];
        if (index > 0 && [toolbar.items[index - 1].itemIdentifier isEqualToString:NSToolbarFlexibleSpaceItemIdentifier]) [toolbar removeItemAtIndex:index - 1];
    }
    self.pane.searchItem.searchField.stringValue = @"";
    [self.pane updateRows];
    if ([self.title.stringValue isEqualToString:@"Patches"]) self.title.stringValue = self.originalTitle;
}
@end

static NSInteger DPSidebar_numberOfRows(id self, SEL _cmd, NSTableView *table) {
    return DPCallOriginal(DPSidebar_numberOfRows, self, table) + 1;
}

static NSView *DPSidebar_viewForRow(id self, SEL _cmd, NSTableView *table, NSTableColumn *column, NSInteger row) {
    if (!DPIsPatchesRow(table, row)) return DPCallOriginal(DPSidebar_viewForRow, self, table, column, row);
    NSTableCellView *cell = [table makeViewWithIdentifier:DPPatchesCellIdentifier owner:nil];
    if (cell) return cell;
    cell = [objc_getClass(DPDiaSettingsSidebarCell) new];
    cell.identifier = DPPatchesCellIdentifier;
    cell.textField.stringValue = @"Patches";
    cell.imageView.image = [NSImage imageWithSystemSymbolName:@"wand.and.stars" accessibilityDescription:@"Patches"];
    return cell;
}

static void DPSidebar_selectionDidChange(id self, SEL _cmd, NSNotification *notification) {
    NSTableView *table = notification.object;
    DPSettings *settings = [DPSettings forTable:table];
    if (DPIsPatchesRow(table, table.selectedRow)) return [settings showPane];
    [settings hidePane];
    DPCallOriginal(DPSidebar_selectionDidChange, self, notification);
}

static NSToolbarItem *DPSettings_toolbarItem(id self, SEL _cmd, NSToolbar *toolbar, NSToolbarItemIdentifier identifier, BOOL willInsert) {
    if ([identifier isEqualToString:DPSearchItemIdentifier]) return DPGet(toolbar, &DPSearchItemKey);
    return DPCallOriginal(DPSettings_toolbarItem, self, toolbar, identifier, willInsert);
}

void DPInstallSettings(void) {
    DPHook(DPDiaSettingsSidebar, @selector(numberOfRowsInTableView:), (IMP)DPSidebar_numberOfRows);
    DPHook(DPDiaSettingsSidebar, @selector(tableView:viewForTableColumn:row:), (IMP)DPSidebar_viewForRow);
    DPHook(DPDiaSettingsSidebar, @selector(tableViewSelectionDidChange:), (IMP)DPSidebar_selectionDidChange);
    DPHook(DPDiaSettingsController, @selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:), (IMP)DPSettings_toolbarItem);
}
