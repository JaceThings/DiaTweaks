#import "KeepSavedTabs.h"

// ✕ on a saved tab, such as one opened from a collapsed folder's hover menu, can delete it from its folder for good. This
// runs the tab's own Close instead, which only closes its page.

static NSMutableArray<NSString *> *DPRecentTabIDs;
static char DPSwallowMouseUpKey;

static void DPRunClose(NSView *tab) {
    NSPoint point = [tab convertPoint:NSMakePoint(NSMidX(tab.bounds), NSMidY(tab.bounds)) toView:nil];
    NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:point modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
                                    windowNumber:tab.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
    NSMenu *menu = [tab menuForEvent:click];
    [menu update];
    for (NSMenuItem *item in menu.itemArray)
        if ([item.title isEqualToString:@"Close"]) return (void)[menu performActionForItemAtIndex:[menu indexOfItem:item]];
}

// A collapsed folder lists the tabs opened from its hover menu, and Dia only drops one from that list by deleting it. After
// closing, the list is reset the way clicking the folder header does: back to just the tab you're on.
static void DPResetFolderList(NSView *list, NSRect tabFrame) {
    NSPoint middle = NSMakePoint(NSMidX(tabFrame), NSMidY(tabFrame));
    NSView *folder = DPFindView(list, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaTabGroupCell) && NSPointInRect([view convertPoint:middle fromView:list], view.bounds);
    });
    if (!folder) return;
    NSView *showMore = DPFindView(folder, ^BOOL(NSView *view) { return DPHasLabel(view, @"Show More"); });
    if (showMore && !showMore.hiddenOrHasHiddenAncestor) return DPSavedClickHeader(folder);
    // With one tab left Dia draws the folder as collapsed, chevron pointing right, and a single click would open it.
    Ivar ivar = class_getInstanceVariable(object_getClass(folder), "$__lazy_storage_$_chevronIconView");
    id chevron = ivar ? object_getIvar(folder, ivar) : nil;
    CATransform3D t = [chevron isKindOfClass:NSView.class] ? ((NSView *)chevron).layer.transform : CATransform3DIdentity;
    if (fabs(atan2(t.m12, t.m11)) < 0.1 || NSHeight(folder.bounds) < 40) return;
    DPSavedClickHeader(folder);
    DPSavedClickHeader(folder);
}

BOOL DPSavedClose(NSView *tab) {
    NSString *tabID = DPSavedTabID(tab);
    NSView *list = DPSavedEnclosing(tab, NSCollectionView.class);
    if (!DPKeepSavedTabs.on || !tabID || !list || !DPSavedKeepsTab(tab)) return NO;
    BOOL selected = DPSavedIsSelected(tab);
    // Closing the tab you're on makes Dia open the next tab in its folder, so it goes back to the previous tab first.
    dispatch_async(dispatch_get_main_queue(), ^{
        [DPRecentTabIDs removeObject:tabID];
        if (selected) {
            NSView *previous = nil;
            for (NSString *recent in DPRecentTabIDs) if ((previous = DPSavedTabWithID(list, recent))) break;
            if (!previous) for (NSView *candidate in DPSavedTabsIn(list)) if (!DPSavedIsSaved(candidate)) { previous = candidate; break; }
            if (previous) DPSavedSelect(previous);
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, selected ? NSEC_PER_SEC / 10 : 0), dispatch_get_main_queue(), ^{
            NSView *current = DPSavedTabWithID(list, tabID);
            if (!current) return;
            NSRect frame = [list convertRect:current.bounds fromView:current];
            DPRunClose(current);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 10), dispatch_get_main_queue(), ^{ DPResetFolderList(list, frame); });
        });
    });
    return YES;
}

// Remembers the tab being left, so closing the next one can come back to it. Hover menu tabs live in their own window.
static void DPRememberSelected(NSView *clicked) {
    NSArray<NSView *> *tabs = DPSavedTabsIn(DPSavedEnclosing(clicked, NSCollectionView.class));
    if ([tabs indexOfObjectPassingTest:^BOOL(NSView *tab, NSUInteger i, BOOL *stop) { return DPSavedIsSelected(tab); }] == NSNotFound)
        tabs = DPSavedTabsIn((NSApp.mainWindow ?: clicked.window).contentView);
    for (NSView *tab in tabs) {
        NSString *tabID = DPSavedIsSelected(tab) ? DPSavedTabID(tab) : nil;
        if (!tabID) continue;
        [DPRecentTabIDs removeObject:tabID];
        [DPRecentTabIDs insertObject:tabID atIndex:0];
        if (DPRecentTabIDs.count > 20) [DPRecentTabIDs removeLastObject];
    }
}

static void DPCloseButton_mouseDown(NSButton *self, SEL _cmd, NSEvent *event) {
    NSView *tab = DPSavedEnclosing(self, objc_getClass(DPDiaTabView));
    if (!DPHasLabel(self, @"Close tab") || !DPSavedClose(tab)) DPCallOriginal(DPCloseButton_mouseDown, self, event);
}

static void DPTab_mouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    NSButton *close = DPSavedCloseButton(self);
    BOOL onClose = close && !close.hiddenOrHasHiddenAncestor && close.alphaValue > 0
        && NSPointInRect([close convertPoint:event.locationInWindow fromView:nil], close.bounds);
    if (onClose && DPSavedClose(self)) return DPSet(self, &DPSwallowMouseUpKey, @YES);
    if (!onClose && !DPSavedSelecting && !DPSavedIsSelected(self)) DPRememberSelected(self);
    DPCallOriginal(DPTab_mouseDown, self, event);
}

static void DPTab_mouseUp(NSView *self, SEL _cmd, NSEvent *event) {
    if ([DPGet(self, &DPSwallowMouseUpKey) boolValue]) DPSet(self, &DPSwallowMouseUpKey, nil);
    else DPCallOriginal(DPTab_mouseUp, self, event);
}

void DPInstallSavedClose(void) {
    DPRecentTabIDs = [NSMutableArray new];
    DPHook(DPDiaHoverableButton, @selector(mouseDown:), (IMP)DPCloseButton_mouseDown);
    DPHook(DPDiaTabView, @selector(mouseDown:), (IMP)DPTab_mouseDown);
    DPHook(DPDiaTabView, @selector(mouseUp:), (IMP)DPTab_mouseUp);
}
