#import "GroupTabs.h"

static const NSInteger DPGroupCommandsTag = 0xD1A7010;
static const NSInteger DPGroupCommandsCount = 4;
static BOOL DPPlacing;

static BOOL DPIsSeparateTabs(NSMenuItem *item) { return [item.title isEqualToString:@"Separate Tabs"]; }

static NSArray<NSMenuItem *> *DPGroupCommands(void) {
    NSMenuItem *separator = NSMenuItem.separatorItem;
    NSArray<NSMenuItem *> *items = @[
        separator,
        DPGroupCommandItem(@"Expand All Groups", @"rectangle.expand.vertical", ^{ DPSetAllGroupsCollapsed(NO); }),
        DPGroupCommandItem(@"Collapse All Groups", @"rectangle.compress.vertical", ^{ DPSetAllGroupsCollapsed(YES); }),
        DPGroupCommandItem(@"Separate All Groups", @"rectangle.split.3x1", ^{ DPSeparateAllGroups(); }),
    ];
    for (NSMenuItem *item in items) {
        item.tag = DPGroupCommandsTag;
        item.hidden = !DPGroupTabs.on;
    }
    return items;
}

BOOL DPHasGroupCommands(NSMenu *menu, NSMenuItem *added) { return DPIsSeparateTabs(added) || [menu itemWithTag:DPGroupCommandsTag]; }

// Dia builds a group's menu an item at a time, so the commands move to the end of Separate Tabs' section as it grows.
void DPPlaceGroupCommands(NSMenu *menu) {
    if (DPPlacing || !menu) return;
    NSInteger anchor = NSNotFound;
    NSMutableArray<NSMenuItem *> *ours = [NSMutableArray array];
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if (item.tag == DPGroupCommandsTag) [ours addObject:item];
        else if (anchor == NSNotFound && DPIsSeparateTabs(item)) anchor = i;
    }
    if (anchor == NSNotFound) return;
    NSInteger end = menu.numberOfItems;
    for (NSInteger i = anchor + 1; i < menu.numberOfItems; i++) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if (item.isSeparatorItem && item.tag != DPGroupCommandsTag) { end = i; break; }
    }
    NSInteger first = ours.count ? [menu indexOfItem:ours.firstObject] : NSNotFound;
    if (ours.count == DPGroupCommandsCount && first == end - DPGroupCommandsCount && [menu indexOfItem:ours.lastObject] == end - 1) return;
    DPPlacing = YES;
    for (NSMenuItem *item in ours) {
        if ([menu indexOfItem:item] < end) end--;
        [menu removeItem:item];
    }
    NSArray<NSMenuItem *> *items = ours.count == DPGroupCommandsCount ? ours : DPGroupCommands();
    for (NSInteger i = 0; i < DPGroupCommandsCount; i++) [menu insertItem:items[i] atIndex:end + i];
    DPPlacing = NO;
}
