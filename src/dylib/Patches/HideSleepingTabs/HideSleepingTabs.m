#import "StdPatch/StdPatch.h"

// The tab switcher (⌃⇥) lists recent tabs, a pinned tab you closed among them, with an empty picture. Those are left out
// of its grid, and the highlight steps over them, so letting go of ⌃ never lands on one.

@interface NSObject (DPSwiftFields)
- (id)safeSwiftValueForKey:(NSString *)key;
@end

extern DPPatch DPHideSleepingTabs;

static id DPField(id object, NSString *key) {
    return [object respondsToSelector:@selector(safeSwiftValueForKey:)] ? [object safeSwiftValueForKey:key] : nil;
}

// Tab IDs are UUIDs, and the switcher's items only come through as their description.
static NSArray<NSString *> *DPSwitcherItems(id viewModel, NSString **focused) {
    id state = DPField(DPField(viewModel, @"stateSubject"), @"currentValue");
    if (focused) *focused = [DPField(state, @"focusedItemID") description];
    NSString *items = [DPField(state, @"items") description] ?: @"";
    static NSRegularExpression *uuid;
    if (!uuid) uuid = [NSRegularExpression regularExpressionWithPattern:@"[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}" options:0 error:nil];
    NSMutableArray *tabs = [NSMutableArray new];
    for (NSTextCheckingResult *match in [uuid matchesInString:items options:0 range:NSMakeRange(0, items.length)])
        [tabs addObject:[items substringWithRange:match.range]];
    return tabs;
}

// A tab with no picture has nothing loaded: a closed pinned tab, or one not opened since Dia started.
static NSSet<NSString *> *DPSleepingTabs(id viewModel) {
    NSDictionary *tabs = DPField(DPField(viewModel, @"delegate"), @"recentTabControllers");
    NSMutableSet *sleeping = [NSMutableSet new];
    for (id tab in tabs) {
        NSString *state = [DPField(DPField(DPField(tabs[tab], @"viewModel"), @"stateSubject"), @"currentValue") description];
        if (state && ![state containsString:@"snapshot: Optional("]) [sleeping addObject:[tab description]];
    }
    return sleeping;
}

// Where each cell the switcher shows sits in its own list.
static NSArray<NSNumber *> *DPShownItems(id list) {
    NSArray<NSString *> *items = DPSwitcherItems(DPField(list, @"viewModel"), NULL);
    NSSet *sleeping = DPHideSleepingTabs.on ? DPSleepingTabs(DPField(list, @"viewModel")) : nil;
    NSMutableArray *shown = [NSMutableArray new];
    [items enumerateObjectsUsingBlock:^(NSString *tab, NSUInteger i, BOOL *stop) { if (![sleeping containsObject:tab]) [shown addObject:@(i)]; }];
    return shown.count ? shown : nil;
}

static NSIndexPath *DPDiaIndexPath(id list, NSIndexPath *path) {
    NSArray<NSNumber *> *shown = DPShownItems(list);
    return shown && path.item < (NSInteger)shown.count ? [NSIndexPath indexPathForItem:shown[path.item].integerValue inSection:path.section] : path;
}

static void DPWatchSwitcherSize(id list);

static NSInteger DPList_count(id self, SEL _cmd, NSCollectionView *view, NSInteger section) {
    DPWatchSwitcherSize(self);
    NSArray *shown = DPShownItems(self);
    return shown ? (NSInteger)shown.count : DPCallOriginal(DPList_count, self, view, section);
}

// Dia makes the cell for its own index, which can be past the end of the shorter grid, so the grid gets the shown one.
static NSIndexPath *DPShownPath;

static NSCollectionViewItem *DPList_item(id self, SEL _cmd, NSCollectionView *view, NSIndexPath *path) {
    DPShownPath = path;
    NSCollectionViewItem *item = DPCallOriginal(DPList_item, self, view, DPDiaIndexPath(self, path));
    DPShownPath = nil;
    return item;
}

static NSCollectionViewItem *DPGrid_makeItem(NSCollectionView *self, SEL _cmd, NSUserInterfaceItemIdentifier identifier, NSIndexPath *path) {
    return DPCallOriginal(DPGrid_makeItem, self, identifier, DPShownPath ?: path);
}

static NSSize DPList_size(id self, SEL _cmd, NSCollectionView *view, NSCollectionViewLayout *layout, NSIndexPath *path) {
    return DPCallOriginal(DPList_size, self, view, layout, DPDiaIndexPath(self, path));
}

static void DPList_select(id self, SEL _cmd, NSCollectionView *view, NSSet<NSIndexPath *> *paths) {
    NSMutableSet *dia = [NSMutableSet new];
    for (NSIndexPath *path in paths) [dia addObject:DPDiaIndexPath(self, path)];
    DPCallOriginal(DPList_select, self, view, dia);
}

// Dia sizes the switcher for all of its tabs, with width and height constraints on the window's content, which the card
// and grid follow and the window takes its frame from. Each time Dia sets one, it's set again for the cells left, before
// any layout, as a frame set any later would fight the constraints.
static const CGFloat DPSwitcherChrome = 152;  // The window's shadow margin and the grid's inset, on both sides.
static char DPWatchedKey;
static BOOL DPFitting;

static void DPFitSwitcherSize(NSLayoutConstraint *size, id list) {
    NSCollectionView *grid = DPField(list, @"collectionView");
    NSArray *shown = DPHideSleepingTabs.on ? DPShownItems(list) : nil;
    if (DPFitting || !grid || !shown) return;
    NSSize cell = [list collectionView:grid layout:grid.collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    BOOL width = size.firstAttribute == NSLayoutAttributeWidth;
    CGFloat step = width ? cell.width : cell.height;
    if (step <= 0) return;
    NSInteger dia = MAX(1, lround((size.constant - DPSwitcherChrome) / step));
    NSInteger columns = MIN((NSInteger)shown.count, dia);
    NSInteger fit = width ? columns : MIN(dia, ((NSInteger)shown.count + columns - 1) / columns);
    DPFitting = YES;
    size.constant = DPSwitcherChrome + fit * step;
    DPFitting = NO;
}

@interface DPSwitcherSizeWatch : NSObject
@property (nonatomic, weak) id list;
@end

@implementation DPSwitcherSizeWatch
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(NSLayoutConstraint *)size change:(NSDictionary *)change context:(void *)context {
    DPFitSwitcherSize(size, self.list);
}
@end

static void DPWatchSwitcherSize(id list) {
    NSView *content = [list view];
    for (NSLayoutConstraint *size in content.constraints) {
        BOOL dimension = size.firstAttribute == NSLayoutAttributeWidth || size.firstAttribute == NSLayoutAttributeHeight;
        if (size.firstItem != content || size.secondItem || !dimension || DPGet(size, &DPWatchedKey)) continue;
        DPSwitcherSizeWatch *watch = [DPSwitcherSizeWatch new];
        watch.list = list;
        [size addObserver:watch forKeyPath:@"constant" options:0 context:NULL];
        DPSet(size, &DPWatchedKey, watch);
        // Asked for its cells mid-layout, so the first fit waits for the pass to end.
        dispatch_async(dispatch_get_main_queue(), ^{ DPFitSwitcherSize(size, list); });
    }
}

static NSWindowController *DPOpenSwitcher(void) {
    for (NSWindow *window in NSApp.windows)
        if (window.visible && DPIsKind(window.windowController, DPDiaTabSwitcher)) return window.windowController;
    return nil;
}

// The switcher moves on ⌃⇥ itself once open, so a step it lands on a hidden tab is followed by another the same way.
// Dia shows the switcher a moment after the first ⌃⇥, so until it's up this keeps looking.
static void DPStepPastSleeping(int tries) {
    NSWindowController *switcher = DPOpenSwitcher();
    id viewModel = DPField(switcher, @"viewModel");
    NSString *focused = nil;
    DPSwitcherItems(viewModel, &focused);
    if (!tries) return;
    if (!focused) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ DPStepPastSleeping(tries - 1); });
        return;
    }
    if (![DPSleepingTabs(viewModel) containsObject:focused]) return;
    NSEventModifierFlags mods = NSEventModifierFlagControl | (NSEvent.modifierFlags & NSEventModifierFlagShift);
    [NSApp postEvent:[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:mods timestamp:NSProcessInfo.processInfo.systemUptime
                                  windowNumber:switcher.window.windowNumber context:nil characters:@"\t" charactersIgnoringModifiers:@"\t" isARepeat:NO keyCode:48]
             atStart:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ DPStepPastSleeping(tries - 1); });
}

static void DPInstallHideSleepingTabs(void) {
    DPHook(DPDiaTabSwitcherList, @selector(collectionView:numberOfItemsInSection:), (IMP)DPList_count);
    DPHook(DPDiaTabSwitcherList, @selector(collectionView:itemForRepresentedObjectAtIndexPath:), (IMP)DPList_item);
    DPHook(DPDiaTabSwitcherList, @selector(collectionView:layout:sizeForItemAtIndexPath:), (IMP)DPList_size);
    DPHook(DPDiaTabSwitcherList, @selector(collectionView:didSelectItemsAtIndexPaths:), (IMP)DPList_select);
    DPHookClass(NSCollectionView.class, @selector(makeItemWithIdentifier:forIndexPath:), (IMP)DPGrid_makeItem);
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (DPHideSleepingTabs.on && event.keyCode == 48 && (event.modifierFlags & NSEventModifierFlagControl))
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ DPStepPastSleeping(20); });
        return event;
    }];
}

DP_PATCH(DPHideSleepingTabs) {
    .key = @"hideSleepingTabs",
    .order = 86,
    .title = @"Hide Sleeping Tabs in Tab Switcher",
    .detail = @"Leave tabs with nothing loaded, like a pinned tab you closed, out of the tab switcher (⌃⇥) instead of showing them as empty pictures.",
    .symbol = @"moon.zzz.fill",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .classes = DPClasses(DPDiaTabSwitcher, DPDiaTabSwitcherList),
    .install = DPInstallHideSleepingTabs,
};
