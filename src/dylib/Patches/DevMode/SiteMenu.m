#import "DevMode.h"

static char DPSiteItemKey;

static NSString *DPHostOfMenu(NSMenu *menu) {
    NSViewController *owner = (NSViewController *)menu.delegate;
    NSView *pane = DPIsKind(owner, DPDiaToolbarController) ? DPPaneAbove(owner.view) : nil;
    return pane ? DPHostOf(DPPageIn(pane)) : nil;
}

static void DPAddSiteItem(NSMenu *menu) {
    for (NSMenuItem *old in menu.itemArray)
        if (DPGet(old, &DPSiteItemKey)) [menu removeItem:old];
    NSInteger settings = [menu indexOfItemWithTitle:@"Site Settings"];
    NSString *host = DPHostOfMenu(menu);
    if (!DPDevMode.on || !host || settings < 0) return;
    BOOL on = DPDevModeOn(host);
    NSMenuItem *item = DPMenuItem(@"Developer Mode", ^{ DPSetDevModeOn(host, !on); });
    item.image = [NSImage imageWithSystemSymbolName:@"hammer" accessibilityDescription:nil];
    item.state = on ? NSControlStateValueOn : NSControlStateValueOff;
    DPSet(item, &DPSiteItemKey, @YES);
    NSInteger toggle = [menu indexOfItemWithTitle:@"Automatic Picture-In-Picture"];
    [menu insertItem:item atIndex:toggle >= 0 ? toggle + 1 : settings];
}

static BOOL DPMenu_popUpAt(NSMenu *self, SEL _cmd, NSMenuItem *item, NSPoint location, NSView *view) {
    DPAddSiteItem(self);
    return DPCallOriginal(DPMenu_popUpAt, self, item, location, view);
}

void DPInstallSiteMenu(void) {
    DPHookClass(NSMenu.class, @selector(popUpMenuPositioningItem:atLocation:inView:), (IMP)DPMenu_popUpAt);
    [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidBeginTrackingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSMenu *menu = note.object;
        BOOL added = NO;
        for (NSMenuItem *each in menu.itemArray) added = added || DPGet(each, &DPSiteItemKey) != nil;
        if (!added && DPIsKind(menu.delegate, DPDiaToolbarController)) DPAddSiteItem(menu);
    }];
}
