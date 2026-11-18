#import "GroupTabs.h"

static const NSInteger DPGroupMenuTag = 0xD1A7001, DPGroupSelectedTag = 0xD1A7006;
static BOOL DPInserting;

@interface DPTabGroupsMenu : NSObject <NSMenuDelegate>
@end

@implementation DPTabGroupsMenu
- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu itemWithTag:DPGroupSelectedTag].hidden = !DPHasSelectedTabs(DPCommandBrowser());
}
@end

static BOOL DPIsNewGroupTitle(NSString *title) {
    if ([title isEqualToString:@"New Group with Tab"] || [title isEqualToString:@"New Group with Tabs"]) return YES;
    return [title hasPrefix:@"New Group with "] && ([title hasSuffix:@" Tab"] || [title hasSuffix:@" Tabs"]);
}

NSMenuItem *DPGroupCommandItem(NSString *title, NSString *symbol, void (^action)(void)) {
    NSMenuItem *item = DPMenuItem(title, action);
    item.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    return item;
}

static BOOL DPIsMenuBarTabs(NSMenu *menu) { return menu.supermenu == NSApp.mainMenu || [menu itemWithTitle:@"Next Tab"]; }

// A tab's right-click menu acts on the window, or on the selected tabs when there are several.
static NSMenuItem *DPTabGroupItem(void) {
    BOOL selected = DPHasSelectedTabs(DPCommandBrowser());
    NSMenuItem *item = selected ? DPGroupCommandItem(@"Group Selected Tabs by Domain", @"rectangle.3.group", ^{ DPGroupSelectedTabsOnce(); })
                                : DPGroupCommandItem(@"Group Tabs by Domain", @"rectangle.3.group", ^{ DPGroupTabsOnce(); });
    item.tag = DPGroupMenuTag;
    item.hidden = !DPGroupTabs.on;
    return item;
}

static NSMenuItem *DPMakeTabGroups(NSMenuItem *item) {
    static DPTabGroupsMenu *delegate;
    delegate = delegate ?: [DPTabGroupsMenu new];
    NSMenu *commands = [[NSMenu alloc] initWithTitle:@"Tab Groups"];
    commands.delegate = delegate;
    [commands addItem:DPGroupCommandItem(@"Group Tabs by Domain", @"rectangle.3.group", ^{ DPGroupTabsOnce(); })];
    NSMenuItem *selected = DPGroupCommandItem(@"Group Selected Tabs by Domain", @"rectangle.3.group", ^{ DPGroupSelectedTabsOnce(); });
    selected.tag = DPGroupSelectedTag;
    selected.hidden = !DPHasSelectedTabs(DPCommandBrowser());
    [commands addItem:selected];
    [commands addItem:NSMenuItem.separatorItem];
    [commands addItem:DPGroupCommandItem(@"Expand All Groups", @"rectangle.expand.vertical", ^{ DPSetAllGroupsCollapsed(NO); })];
    [commands addItem:DPGroupCommandItem(@"Collapse All Groups", @"rectangle.compress.vertical", ^{ DPSetAllGroupsCollapsed(YES); })];
    [commands addItem:NSMenuItem.separatorItem];
    [commands addItem:DPGroupCommandItem(@"Separate This Domain", @"rectangle.split.2x1", ^{ DPSeparateDomain(); })];
    [commands addItem:DPGroupCommandItem(@"Separate All Groups", @"rectangle.split.3x1", ^{ DPSeparateAllGroups(); })];
    item.title = commands.title;
    item.action = NULL;
    item.target = nil;
    item.representedObject = nil;
    item.tag = DPGroupMenuTag;
    item.image = [NSImage imageWithSystemSymbolName:@"rectangle.3.group" accessibilityDescription:nil];
    item.submenu = commands;
    item.hidden = !DPGroupTabs.on;
    return item;
}

static NSMenuItem *DPGroupMenuItem(void) { return DPMakeTabGroups([[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""]); }

// Dia removes the tagged copies it added, so keep the last item with the tag: dropping Dia's copy crashes Dia.
// Dia fills the Tabs menu with copies of a tab's right-click items, so the copy there becomes Tab Groups in place.
static void DPPlaceGroupItem(NSMenu *menu) {
    if (DPInserting || !menu) return;
    NSInteger anchor = NSNotFound, visible = NSNotFound, existing = NSNotFound;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if (item.tag == DPGroupMenuTag) existing = i;
        else if (DPIsNewGroupTitle(item.title)) {
            if (!item.hidden && visible == NSNotFound) visible = i;
            if (anchor == NSNotFound) anchor = i;
        }
    }
    if (visible != NSNotFound) anchor = visible;
    if (anchor == NSNotFound) return;
    DPInserting = YES;
    for (NSInteger i = menu.numberOfItems - 1; i >= 0; i--)
        if ([menu itemAtIndex:i].tag == DPGroupMenuTag && i != existing) {
            [menu removeItemAtIndex:i];
            if (i < existing) existing--;
            if (i < anchor) anchor--;
        }
    DPInserting = NO;
    if (existing != NSNotFound && !menu.itemArray[existing].submenu && DPIsMenuBarTabs(menu)) DPMakeTabGroups(menu.itemArray[existing]);
    NSInteger end = menu.numberOfItems;
    for (NSInteger i = anchor + 1; i < menu.numberOfItems; i++)
        if ([menu itemAtIndex:i].isSeparatorItem) { end = i; break; }
    if (existing != NSNotFound && existing == end - 1) return;
    DPInserting = YES;
    NSMenuItem *item = existing != NSNotFound ? [menu itemAtIndex:existing] : DPIsMenuBarTabs(menu) ? DPGroupMenuItem() : DPTabGroupItem();
    if (existing != NSNotFound) {
        [menu removeItemAtIndex:existing];
        if (existing < end) end--;
    }
    [menu insertItem:item atIndex:end];
    DPInserting = NO;
}

static void DPInstallMenuBarItem(void) {
    NSMenu *tabMenu = nil, *commandMenu = nil, *windowMenu = nil, *fileMenu = nil;
    for (NSMenuItem *top in NSApp.mainMenu.itemArray) {
        NSString *title = top.title ?: @"";
        if ([title isEqualToString:@"Tab"] || [title isEqualToString:@"Tabs"]) tabMenu = top.submenu;
        if ([title isEqualToString:@"Window"]) windowMenu = top.submenu;
        if ([title isEqualToString:@"File"]) fileMenu = top.submenu;
        for (NSMenuItem *item in top.submenu.itemArray)
            if (DPIsNewGroupTitle(item.title) || [item.title isEqualToString:@"New Tab"] || [item.title isEqualToString:@"Close Tab"]
                || [item.title isEqualToString:@"Select Next Tab"] || [item.title isEqualToString:@"Reopen Closed Tab"])
                commandMenu = top.submenu;
    }
    NSMenu *menu = tabMenu ?: commandMenu ?: windowMenu ?: fileMenu;
    if (!menu || [menu itemWithTag:DPGroupMenuTag]) return;
    for (NSMenuItem *item in menu.itemArray)
        if (DPIsNewGroupTitle(item.title)) return DPPlaceGroupItem(menu);
    NSInteger index = menu.numberOfItems;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSString *title = [menu itemAtIndex:i].title;
        if (DPIsNewGroupTitle(title) || [title isEqualToString:@"New Tab"]) index = i + 1;
    }
    DPInserting = YES;
    [menu insertItem:DPGroupMenuItem() atIndex:MIN(index, menu.numberOfItems)];
    DPInserting = NO;
}

static void DPMenuAdded(NSMenu *menu, NSMenuItem *item) {
    if (!DPInserting && (DPIsNewGroupTitle(item.title) || [menu itemWithTag:DPGroupMenuTag])) DPPlaceGroupItem(menu);
    if (DPHasGroupCommands(menu, item)) DPPlaceGroupCommands(menu);
}

static void DPMenu_addItem(NSMenu *self, SEL _cmd, NSMenuItem *item) {
    DPCallOriginal(DPMenu_addItem, self, item);
    DPMenuAdded(self, item);
}

static void DPMenu_insertItem(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    DPCallOriginal(DPMenu_insertItem, self, item, index);
    DPMenuAdded(self, item);
}

void DPInstallGroupMenus(void) {
    DPHookClass(NSMenu.class, @selector(addItem:), (IMP)DPMenu_addItem);
    DPHookClass(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPMenu_insertItem);
    DPOnLaunch(^{ DPInstallMenuBarItem(); });
}

static void DPApplyGroupTabs(DPPatch *patch) {
    for (NSMenuItem *top in NSApp.mainMenu.itemArray) [top.submenu itemWithTag:DPGroupMenuTag].hidden = !patch->on;
}

static NSString *DPVerifyGroupTabs(DPPatch *patch) {
    NSMenuItem *item = nil;
    for (NSMenuItem *top in NSApp.mainMenu.itemArray) item = item ?: [top.submenu itemWithTag:DPGroupMenuTag];
    if (!item) return @"Tab Groups isn't in the menu bar";
    if (item.hidden == patch->on) return patch->on ? @"Tab Groups is hidden" : @"Tab Groups still shows";
    if (![item.submenu itemWithTitle:@"Group Tabs by Domain"] || ![item.submenu itemWithTitle:@"Separate All Groups"])
        return @"a group command is missing from Tab Groups";
    if (patch->on && !DPCanReadSelection(DPCommandBrowser())) return @"can't read which tabs are selected";
    return nil;
}

DP_PATCH(DPGroupTabs) {
    .key = @"groupTabsByDomain",
    .order = 86,
    .defaultOn = YES,
    .title = @"Group Tabs by Domain",
    .detail = @"Groups a window’s tabs by site, from Tab Groups in the Tabs menu or a tab’s right-click menu, or with a shortcut.",
    .symbol = @"rectangle.3.group.fill",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .install = DPInstallGroupTabs,
    .apply = DPApplyGroupTabs,
    .verify = DPVerifyGroupTabs,
    .shortcut = @"groupTabsByDomainShortcut",
    .defaultShortcut = DPDefaultGroupTabsShortcut,
};
