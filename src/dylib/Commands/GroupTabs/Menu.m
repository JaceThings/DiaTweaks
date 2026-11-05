#import "GroupTabs.h"

static const NSInteger DPGroupMenuTag = 0xD1A7001, DPExpandMenuTag = 0xD1A7004, DPCollapseMenuTag = 0xD1A7005;
static NSString *const DPGroupMenuTitle = @"Group Tabs by Domain";
static NSString *const DPExpandMenuTitle = @"Expand All Tab Groups";
static NSString *const DPCollapseMenuTitle = @"Collapse All Tab Groups";
static const NSInteger DPFollowerTags[] = {DPExpandMenuTag, DPCollapseMenuTag};
static const NSInteger DPFollowerCount = sizeof(DPFollowerTags) / sizeof(DPFollowerTags[0]);
static BOOL DPInserting;

static BOOL DPIsFollowerTag(NSInteger tag) {
    for (NSInteger i = 0; i < DPFollowerCount; i++)
        if (DPFollowerTags[i] == tag) return YES;
    return NO;
}

static BOOL DPHasFollower(NSMenu *menu) {
    for (NSInteger i = 0; i < DPFollowerCount; i++)
        if ([menu itemWithTag:DPFollowerTags[i]]) return YES;
    return NO;
}

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

static NSMenuItem *DPFollowerItem(NSInteger tag) {
    if (tag == DPExpandMenuTag)
        return DPCommandItem(DPExpandMenuTitle, tag, @"rectangle.expand.vertical", ^{ DPSetAllGroupsCollapsed(NO); });
    return DPCommandItem(DPCollapseMenuTitle, tag, @"rectangle.compress.vertical", ^{ DPSetAllGroupsCollapsed(YES); });
}

// How many of Expand and Collapse already sit, in order, on the lines right after `index`.
static NSInteger DPFollowersInPlace(NSMenu *menu, NSInteger index) {
    NSInteger n = 0;
    while (n < DPFollowerCount && index + 1 + n < menu.numberOfItems && [menu itemAtIndex:index + 1 + n].tag == DPFollowerTags[n]) n++;
    return n;
}

// Expand, then Collapse, sit on the lines under Group Tabs by Domain. Context menus are built each time they open.
// Dia rebuilds the Tabs menu by adding copies of the items in it, tags and all, and later removes those copies itself, so
// the last item with a tag is the one to keep. Dropping Dia's copy instead crashes Dia when it goes to remove it.
static void DPPlaceFollowerItems(NSMenu *menu) {
    if (DPInserting || !menu) return;
    NSInteger group = NSNotFound, count = 0;
    NSMutableDictionary<NSNumber *, NSMenuItem *> *kept = [NSMutableDictionary dictionary];
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if (item.tag == DPGroupMenuTag && group == NSNotFound) group = i;
        if (!DPIsFollowerTag(item.tag)) continue;
        kept[@(item.tag)] = item;
        count++;
    }
    if (group == NSNotFound || (count == DPFollowerCount && DPFollowersInPlace(menu, group) == DPFollowerCount)) return;
    DPInserting = YES;
    for (NSInteger i = menu.numberOfItems - 1; i >= 0; i--) {
        if (!DPIsFollowerTag([menu itemAtIndex:i].tag)) continue;
        [menu removeItemAtIndex:i];
        if (i < group) group--;
    }
    for (NSInteger n = 0; n < DPFollowerCount; n++)
        [menu insertItem:kept[@(DPFollowerTags[n])] ?: DPFollowerItem(DPFollowerTags[n]) atIndex:group + 1 + n];
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
    if (existing != NSNotFound && existing == end - 1 - DPFollowersInPlace(menu, existing)) return DPPlaceFollowerItems(menu);
    DPInserting = YES;
    NSMenuItem *item = existing != NSNotFound ? [menu itemAtIndex:existing] : DPGroupMenuItem();
    if (existing != NSNotFound) {
        [menu removeItemAtIndex:existing];
        if (existing < end) end--;
    }
    [menu insertItem:item atIndex:end];
    DPInserting = NO;
    DPPlaceFollowerItems(menu);
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
    if ([menu itemWithTag:DPGroupMenuTag]) return DPPlaceFollowerItems(menu);
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
    DPPlaceFollowerItems(menu);
}

static void DPMenu_addItem(NSMenu *self, SEL _cmd, NSMenuItem *item) {
    DPCallOriginal(DPMenu_addItem, self, item);
    if (!DPInserting && (DPIsNewGroupTitle(item.title) || [self itemWithTag:DPGroupMenuTag] || DPHasFollower(self)))
        DPPlaceGroupItem(self);
}

static void DPMenu_insertItem(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    DPCallOriginal(DPMenu_insertItem, self, item, index);
    if (!DPInserting && (DPIsNewGroupTitle(item.title) || [self itemWithTag:DPGroupMenuTag] || DPHasFollower(self)))
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
        for (NSInteger i = 0; i < DPFollowerCount; i++) [top.submenu itemWithTag:DPFollowerTags[i]].hidden = !patch->on;
    }
}

DP_PATCH(DPGroupTabs) {
    .key = @"groupTabsByDomain",
    .order = 86,
    .defaultOn = YES,
    .title = @"Group Tabs by Domain",
    .detail = @"Adds Group Tabs by Domain, Expand All Tab Groups and Collapse All Tab Groups to the tab right-click menu and the Tabs menu. Grouping puts a window’s tabs together by site, also with a shortcut, ⌃⇧G unless you set another. Expand All and Collapse All open or close every group in the front window.",
    .symbol = @"rectangle.3.group.fill",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .install = DPInstallGroupTabs,
    .apply = DPApplyGroupTabs,
    .shortcut = @"groupTabsByDomainShortcut",
    .defaultShortcut = DPDefaultGroupTabsShortcut,
};
