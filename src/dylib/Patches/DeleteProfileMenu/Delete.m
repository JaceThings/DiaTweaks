#import "Patches/DeleteProfileMenu/DeleteProfileMenu.h"

// Settings while it's hidden for a delete; the browser window the confirmation sheet is on.
static __weak NSWindow *DPHiddenSettings, *DPSheetHost;
static NSMutableArray *DPObservers;

static NSWindow *DPConfirmSheet(NSWindow *window) {
    for (NSWindow *sheet in window.sheets)
        if (DPIsKind(sheet.windowController, DPDiaDialogPanelWC)) return sheet;
    return nil;
}

BOOL DPDeletingProfile(void) { return DPSheetHost != nil; }

static void DPObserve(NSNotificationName name, id object, void (^block)(void)) {
    if (!DPObservers) DPObservers = [NSMutableArray new];
    [DPObservers addObject:[NSNotificationCenter.defaultCenter addObserverForName:name object:object queue:nil usingBlock:^(NSNotification *note) { block(); }]];
}

// Done: closes Settings if it's still hidden, putting back what hiding it changed first.
static void DPFinishDelete(BOOL closeSettings) {
    for (id observer in DPObservers) [NSNotificationCenter.defaultCenter removeObserver:observer];
    [DPObservers removeAllObjects];
    NSWindow *settings = DPHiddenSettings;
    DPHiddenSettings = DPSheetHost = nil;
    if (!settings || !DPSettingsHidden(settings)) return;
    if (closeSettings) [settings orderOut:nil];
    DPShowSettings(settings);
    if (closeSettings) [settings close];
    else [settings makeKeyAndOrderFront:nil];  // Leave Settings open on Profiles, as Profile Settings would.
}

// Turning the option off: cancel a confirmation that's up, which ends the delete.
void DPEndProfileDelete(void) {
    NSWindow *sheet = DPConfirmSheet(DPSheetHost);
    NSView *cancel = DPFindView(sheet.contentView, ^BOOL(NSView *v) { return DPHasLabel(v, @"Cancel"); });
    if (!cancel || ![cancel accessibilityPerformPress]) DPFinishDelete(YES);
}

static NSMenuItem *DPRowDeleteItem(NSWindow *settings, NSString *name, NSUInteger index) {
    NSTableView *table = (NSTableView *)DPFindView(settings.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaProfilesTable); });
    if ((NSInteger)index >= table.numberOfRows) return nil;
    // The row for this profile, matched by both its place and its name.
    NSView *cell = [table viewAtColumn:0 row:index makeIfNecessary:YES];
    if (!DPFindView(cell, ^BOOL(NSView *v) { return [v isKindOfClass:NSTextField.class] && [((NSTextField *)v).stringValue isEqual:name]; })) return nil;
    NSRect rect = [table rectOfRow:index];
    NSPoint point = [table convertPoint:NSMakePoint(NSMidX(rect), NSMidY(rect)) toView:nil];
    NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:point modifierFlags:0 timestamp:0
        windowNumber:settings.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
    NSMenu *menu = [table menuForEvent:click];
    if ([menu.delegate respondsToSelector:@selector(menuNeedsUpdate:)]) [menu.delegate menuNeedsUpdate:menu];  // Dia fills it as it opens.
    NSMenuItem *item = [menu itemWithTitle:@"Delete Profile…"];
    [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
    // The menu never opened, so tell the table it closed, which clears its right-clicked row.
    if (menu) [NSNotificationCenter.defaultCenter postNotificationName:NSMenuDidEndTrackingNotification object:menu];
    return item;
}

// Never confirm for a profile the user didn't pick: the sheet must name it.
static BOOL DPSheetNames(NSWindow *sheet, NSString *name) {
    NSString *quoted = [NSString stringWithFormat:@"“%@”", name];
    return DPFindView(sheet.contentView, ^BOOL(NSView *v) { return [v isKindOfClass:NSTextView.class] && [((NSTextView *)v).string containsString:quoted]; }) != nil;
}

static void DPWatchSheet(NSWindow *window, NSString *name, int tries) {
    NSWindow *sheet = DPConfirmSheet(window);
    if (!sheet && tries > 0) {
        __weak NSWindow *weak = window;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            if (weak && DPSheetHost == weak) DPWatchSheet(weak, name, tries - 1);
        });
        return;
    }
    if (!sheet) return DPFinishDelete(NO);
    if (!DPSheetNames(sheet, name)) return DPEndProfileDelete();
    __weak NSWindow *weak = window;
    DPObserve(NSWindowDidEndSheetNotification, window, ^{ if (!DPConfirmSheet(weak)) DPFinishDelete(YES); });
}

void DPDeleteProfile(NSWindow *window, NSString *name, NSUInteger index, NSMenuItem *settingsItem) {
    if (DPSheetHost || DPConfirmSheet(window)) return;
    // Settings that's open, or in the Dock, stays as it is. Otherwise hide it before Dia shows it.
    BOOL wasOpen = DPSettingsWindow(YES) != nil;
    if (!wasOpen) DPHideSettings(DPSettingsWindow(NO));
    [NSApp sendAction:settingsItem.action to:settingsItem.target from:settingsItem];
    NSWindow *settings = DPSettingsWindow(YES);
    if (!settings) return DPShowSettings(DPSettingsWindow(NO));
    DPSheetHost = window;
    if (!wasOpen) {
        DPHideSettings(settings);
        DPHiddenSettings = settings;
        // Opened another way meanwhile (⌘, or the Window menu): it's the user's now.
        __weak NSWindow *weakSettings = settings;
        DPObserve(NSWindowDidBecomeKeyNotification, settings, ^{
            DPShowSettings(weakSettings);
            DPHiddenSettings = nil;
        });
    }
    DPObserve(NSWindowWillCloseNotification, window, ^{ DPFinishDelete(YES); });
    // Dia puts the confirmation on the key window, and fills Settings' list on the next pass.
    [window makeKeyAndOrderFront:nil];
    __weak NSWindow *weak = window;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!weak || DPSheetHost != weak) return;
        if (!DPRowDeleteItem(settings, name, index)) return DPFinishDelete(NO);
        DPWatchSheet(weak, name, 20);
    });
}
