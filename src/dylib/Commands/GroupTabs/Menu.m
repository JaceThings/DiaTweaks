#import "GroupTabs.h"

static const NSInteger DPGroupMenuTag = 0xD1A7001, DPCollapseMenuTag = 0xD1A7005;
static NSString *const DPGroupMenuTitle = @"Group Tabs by Domain";
static NSString *const DPCollapseMenuTitle = @"Collapse All Tab Groups";
static BOOL DPInserting;

static BOOL DPIsNewGroupTitle(NSString *title) {
    if ([title isEqualToString:@"New Group with Tab"] || [title isEqualToString:@"New Group with Tabs"]) return YES;
    return [title hasPrefix:@"New Group with "] && ([title hasSuffix:@" Tab"] || [title hasSuffix:@" Tabs"]);
}

extern DPPatch DPGroupTabs;

static NSMenuItem *DPCommandItem(NSString *title, NSInteger tag, NSString *symbol, void (^action)(void)) {
    NSMenuItem *item = DPMenuItem(title, action);
    item.tag = tag;
    item.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    item.hidden = !DPGroupTabs.on;
    return item;
}

static NSMenuItem *DPGroupMenuItem(void) {
    return DPCommandItem(DPGroupMenuTitle, DPGroupMenuTag, @"rectangle.3.group", ^{ DPGroupTabsOnce(); });
}

static NSMenuItem *DPCollapseMenuItem(void) {
    return DPCommandItem(DPCollapseMenuTitle, DPCollapseMenuTag, @"rectangle.compress.vertical", ^{ DPCollapseAllGroups(); });
}

// Sits on the line under Group Tabs by Domain. Context menus are built each time they open.
static void DPPlaceCollapseItem(NSMenu *menu) {
    if (DPInserting || !menu) return;
    NSInteger group = NSNotFound, existing = NSNotFound;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSInteger tag = [menu itemAtIndex:i].tag;
        if (tag == DPGroupMenuTag && group == NSNotFound) group = i;
        else if (tag == DPCollapseMenuTag && existing == NSNotFound) existing = i;
    }
    if (group == NSNotFound) return;
    DPInserting = YES;
    for (NSInteger i = menu.numberOfItems - 1; i >= 0; i--)
        if ([menu itemAtIndex:i].tag == DPCollapseMenuTag && i != existing) {
            [menu removeItemAtIndex:i];
            if (i < existing) existing--;
            if (i < group) group--;
        }
    if (existing == group + 1) {
        DPInserting = NO;
        return;
    }
    NSMenuItem *item = existing != NSNotFound ? [menu itemAtIndex:existing] : DPCollapseMenuItem();
    if (existing != NSNotFound) {
        [menu removeItemAtIndex:existing];
        if (existing < group) group--;
    }
    [menu insertItem:item atIndex:group + 1];
    DPInserting = NO;
}

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
    NSInteger end = menu.numberOfItems;
    for (NSInteger i = anchor + 1; i < menu.numberOfItems; i++)
        if ([menu itemAtIndex:i].isSeparatorItem) { end = i; break; }
    BOOL paired = existing != NSNotFound && existing + 1 < menu.numberOfItems && existing == end - 2
        && [menu itemAtIndex:existing + 1].tag == DPCollapseMenuTag;
    if (existing == end - 1 || paired) return DPPlaceCollapseItem(menu);
    DPInserting = YES;
    NSMenuItem *item = existing != NSNotFound ? [menu itemAtIndex:existing] : DPGroupMenuItem();
    if (existing != NSNotFound) {
        [menu removeItemAtIndex:existing];
        if (existing < end) end--;
    }
    [menu insertItem:item atIndex:end];
    DPInserting = NO;
    DPPlaceCollapseItem(menu);
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
    if (!menu) return;
    if ([menu itemWithTag:DPGroupMenuTag]) return DPPlaceCollapseItem(menu);
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
    DPPlaceCollapseItem(menu);
}

static void DPMenu_addItem(NSMenu *self, SEL _cmd, NSMenuItem *item) {
    DPCallOriginal(DPMenu_addItem, self, item);
    if (!DPInserting && (DPIsNewGroupTitle(item.title) || [self itemWithTag:DPGroupMenuTag] || [self itemWithTag:DPCollapseMenuTag]))
        DPPlaceGroupItem(self);
}

static void DPMenu_insertItem(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    DPCallOriginal(DPMenu_insertItem, self, item, index);
    if (!DPInserting && (DPIsNewGroupTitle(item.title) || [self itemWithTag:DPGroupMenuTag] || [self itemWithTag:DPCollapseMenuTag]))
        DPPlaceGroupItem(self);
}

void DPInstallGroupMenus(void) {
    DPHookClass(NSMenu.class, @selector(addItem:), (IMP)DPMenu_addItem);
    DPHookClass(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPMenu_insertItem);
    DPOnLaunch(^{ DPInstallMenuBarItem(); });
}

// Tab context menus are built each time they open, so only the Tabs menu keeps an item to hide.
static void DPApplyGroupTabs(DPPatch *patch) {
    for (NSMenuItem *top in NSApp.mainMenu.itemArray) {
        [top.submenu itemWithTag:DPGroupMenuTag].hidden = !patch->on;
        [top.submenu itemWithTag:DPCollapseMenuTag].hidden = !patch->on;
    }
}

DP_PATCH(DPGroupTabs) {
    .key = @"groupTabsByDomain",
    .order = 86,
    .defaultOn = YES,
    .title = @"Group Tabs by Domain",
    .detail = @"Adds Group Tabs by Domain and Collapse All Tab Groups to the tab right-click menu and the Tabs menu. Grouping puts a window’s tabs together by site. Collapse All collapses every expanded group in the front window.",
    .symbol = @"rectangle.3.group.fill",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .install = DPInstallGroupTabs,
    .apply = DPApplyGroupTabs,
};
