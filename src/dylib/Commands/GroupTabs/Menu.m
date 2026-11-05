#import "GroupTabs.h"

static const NSInteger DPGroupMenuTag = 0xD1A7001;
static const NSInteger DPGroupAllMenuTag = 0xD1A7002;
static NSString *const DPGroupMenuTitle = @"Group Tabs by Domain";
static NSString *const DPGroupAllMenuTitle = @"Group Tabs by Domain in All Windows";
static BOOL DPInserting;

static BOOL DPIsNewGroupTitle(NSString *title) {
    if ([title isEqualToString:@"New Group with Tab"] || [title isEqualToString:@"New Group with Tabs"]) return YES;
    return [title hasPrefix:@"New Group with "] && ([title hasSuffix:@" Tab"] || [title hasSuffix:@" Tabs"]);
}

extern DPPatch DPGroupTabs;

static NSMenuItem *DPMakeGroupItem(BOOL allWindows) {
    NSString *title = DPGroupMenuTitle;
    void (^action)(void) = ^{ DPGroupTabsOnce(); };
    NSInteger tag = DPGroupMenuTag;
    if (allWindows) {
        title = DPGroupAllMenuTitle;
        action = ^{ DPGroupTabsAllWindows(); };
        tag = DPGroupAllMenuTag;
    }
    NSMenuItem *item = DPMenuItem(title, action);
    item.tag = tag;
    item.image = [NSImage imageWithSystemSymbolName:@"rectangle.3.group" accessibilityDescription:nil];
    item.hidden = !DPGroupTabs.on;
    return item;
}

static NSMenuItem *DPPullTag(NSMenu *menu, NSInteger tag, NSInteger *end) {
    NSMenuItem *kept = nil;
    for (NSInteger i = menu.numberOfItems - 1; i >= 0; i--) {
        if ([menu itemAtIndex:i].tag != tag) continue;
        if (!kept) kept = [menu itemAtIndex:i];
        [menu removeItemAtIndex:i];
        if (i < *end) (*end)--;
    }
    return kept;
}

static void DPPlaceGroupItem(NSMenu *menu) {
    if (DPInserting || !menu) return;
    NSMenuItem *anchorItem = nil;
    for (NSMenuItem *item in menu.itemArray) {
        if (!DPIsNewGroupTitle(item.title)) continue;
        if (!item.hidden) { anchorItem = item; break; }
        if (!anchorItem) anchorItem = item;
    }
    if (!anchorItem) return;
    NSInteger anchor = [menu indexOfItem:anchorItem];
    NSInteger end = menu.numberOfItems;
    for (NSInteger i = anchor + 1; i < menu.numberOfItems; i++)
        if ([menu itemAtIndex:i].isSeparatorItem) { end = i; break; }
    NSInteger singleAt = [menu indexOfItemWithTag:DPGroupMenuTag];
    NSInteger allAt = [menu indexOfItemWithTag:DPGroupAllMenuTag];
    NSInteger copies = 0;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSInteger tag = [menu itemAtIndex:i].tag;
        if (tag == DPGroupMenuTag || tag == DPGroupAllMenuTag) copies++;
    }
    if (copies == 2 && singleAt != NSNotFound && allAt == singleAt + 1 && allAt + 1 == end) return;
    DPInserting = YES;
    NSMenuItem *single = DPPullTag(menu, DPGroupMenuTag, &end) ?: DPMakeGroupItem(NO);
    NSMenuItem *all = DPPullTag(menu, DPGroupAllMenuTag, &end) ?: DPMakeGroupItem(YES);
    single.hidden = all.hidden = !DPGroupTabs.on;
    if (end > menu.numberOfItems) end = menu.numberOfItems;
    [menu insertItem:single atIndex:end];
    [menu insertItem:all atIndex:end + 1];
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
    if (!menu || ([menu itemWithTag:DPGroupMenuTag] && [menu itemWithTag:DPGroupAllMenuTag])) return;
    for (NSMenuItem *item in menu.itemArray)
        if (DPIsNewGroupTitle(item.title)) return DPPlaceGroupItem(menu);
    NSInteger index = menu.numberOfItems;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSString *title = [menu itemAtIndex:i].title;
        if (DPIsNewGroupTitle(title) || [title isEqualToString:@"New Tab"]) index = i + 1;
    }
    DPInserting = YES;
    if (![menu itemWithTag:DPGroupMenuTag]) [menu insertItem:DPMakeGroupItem(NO) atIndex:MIN(index, menu.numberOfItems)];
    NSInteger after = [menu indexOfItemWithTag:DPGroupMenuTag];
    if (![menu itemWithTag:DPGroupAllMenuTag])
        [menu insertItem:DPMakeGroupItem(YES) atIndex:MIN((after == NSNotFound ? index : after) + 1, menu.numberOfItems)];
    DPInserting = NO;
}

static BOOL DPAffectsGroupMenu(NSMenu *menu, NSMenuItem *item) {
    return DPIsNewGroupTitle(item.title) || [menu itemWithTag:DPGroupMenuTag] || [menu itemWithTag:DPGroupAllMenuTag];
}

static void DPMenu_addItem(NSMenu *self, SEL _cmd, NSMenuItem *item) {
    DPCallOriginal(DPMenu_addItem, self, item);
    if (!DPInserting && DPAffectsGroupMenu(self, item)) DPPlaceGroupItem(self);
}

static void DPMenu_insertItem(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    DPCallOriginal(DPMenu_insertItem, self, item, index);
    if (!DPInserting && DPAffectsGroupMenu(self, item)) DPPlaceGroupItem(self);
}

void DPInstallGroupMenus(void) {
    DPHookClass(NSMenu.class, @selector(addItem:), (IMP)DPMenu_addItem);
    DPHookClass(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPMenu_insertItem);
    DPOnLaunch(^{ DPInstallMenuBarItem(); });
}

// Tab context menus are built each time they open, so only the Tabs menu keeps items to hide.
static void DPApplyGroupTabs(DPPatch *patch) {
    BOOL hidden = !patch->on;
    for (NSMenuItem *top in NSApp.mainMenu.itemArray) {
        [top.submenu itemWithTag:DPGroupMenuTag].hidden = hidden;
        [top.submenu itemWithTag:DPGroupAllMenuTag].hidden = hidden;
    }
}

DP_PATCH(DPGroupTabs) {
    .key = @"groupTabsByDomain",
    .order = 86,
    .defaultOn = YES,
    .title = @"Group Tabs by Domain",
    .detail = @"Adds Group Tabs by Domain and Group Tabs by Domain in All Windows to the tab right-click menu and the Tabs menu. The first groups the front window’s tabs by site; the second groups every open window.",
    .symbol = @"rectangle.3.group.fill",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .install = DPInstallGroupTabs,
    .apply = DPApplyGroupTabs,
};
