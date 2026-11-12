#import "Patches/CommandBar/HideTab.h"
#import "Patches/CommandBar/Tabs.h"

extern DPPatch DPCommandBar;

static NSMutableSet<NSString *> *DPHidden, *DPParked;
static CFTimeInterval DPExpectUntil;
static NSSet<NSString *> *DPKnown;  // The window's tabs when a new one was asked for.

static BOOL DPHiding(void) { return DPCommandBar.on && DPCommandBarHideTab.on; }
static BOOL DPExpecting(void) { return CACurrentMediaTime() < DPExpectUntil; }

// A parked tab is hidden with no bar open, so the lists close up around it rather than hold still.
BOOL DPHidingATab(void) {
    if (!DPHiding()) return NO;
    for (NSString *tab in DPHidden) if (![DPParked containsObject:tab]) return YES;
    return DPExpecting();
}

BOOL DPParksTab(NSString *tab) { return DPHidesTab(tab) && [DPParked containsObject:tab]; }
BOOL DPParkingAny(void) { return DPHiding() && DPParked.count; }

void DPHideBlank(NSString *tabID, BOOL hidden) {
    if (!tabID || (hidden && !DPHiding())) return;
    if (hidden) [DPHidden addObject:tabID];
    else [DPHidden removeObject:tabID];
    DPParkTab(tabID, hidden);
}

void DPParkTab(NSString *tabID, BOOL parked) {
    if (!tabID) return;
    if (parked) [DPParked addObject:tabID];
    else [DPParked removeObject:tabID];
    DPRelayoutLists();
}

BOOL DPHidesTab(NSString *tab) {
    if (!DPHiding() || !tab) return NO;
    return [DPHidden containsObject:tab] || (DPExpecting() && DPKnown && ![DPKnown containsObject:tab]);
}

void DPExpectNewTab(NSWindow *window) {
    if (!DPHiding()) return;
    // Every window's, so one waiting for its own new tab doesn't take another's tabs for new.
    NSMutableSet *known = [NSMutableSet set];
    for (NSWindow *each in NSApp.windows) {
        [known addObjectsFromArray:DPListedTabs(each)];
        for (id tab in [DPScriptWindow(each) valueForKey:@"appleScriptTabs"]) [known addObject:DPTabID(tab) ?: @""];
    }
    for (NSView *tab in DPFindViews(DPDiaTabView)) [known addObject:DPStripTabID(tab) ?: @""];
    DPKnown = known;
    CFTimeInterval until = DPExpectUntil = CACurrentMediaTime() + 1;
    DPFreezeLists(window);
    DPHoldStrips(window);
    // A new tab the bar doesn't open over, such as one in a split, shows once the wait is over.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC + 10 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (DPExpectUntil == until) DPStopExpecting();
    });
}

void DPStopExpecting(void) {
    if (!DPExpectUntil) return;
    DPExpectUntil = 0;
    DPRelayoutLists();
}

void DPHideTabRow(NSString *tabID, NSWindow *window) {
    if (!tabID || !DPHiding()) return;
    [DPHidden addObject:tabID];
    DPExpectUntil = 0;
    // Already so, unless the tab came some way not seen coming: then it's hidden where it is.
    DPFreezeLists(window);
    DPHoldStrips(window);
    DPRelayoutLists();
}

void DPShowTabRow(NSString *tabID, BOOL closing) {
    if (!tabID || ![DPHidden containsObject:tabID]) return;
    // A tab being closed stays hidden until it's gone, so it doesn't come back on the way out.
    if (closing) return (void)dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ DPShowTabRow(tabID, NO); });
    [DPHidden removeObject:tabID];
    [DPParked removeObject:tabID];
    DPRelayoutLists();
}

static void DPApplyHideTab(DPPatch *patch) {
    DPRelayoutLists();
    DPRefreshStandIns();
}

static NSString *DPVerifyHideTab(DPPatch *patch) { return DPVerifyHiddenRows(); }

static void DPInstallHideTab(void) {
    DPHidden = [NSMutableSet set];
    DPParked = [NSMutableSet set];
    DPInstallFrozenLists();
    // The New Tab menu item, however it's chosen, before it makes the tab.
    [NSNotificationCenter.defaultCenter addObserverForName:NSMenuWillSendActionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSMenuItem *item = note.userInfo[@"MenuItem"];
        if ([item.title isEqualToString:@"New Tab"] && NSApp.keyWindow) DPExpectNewTab(NSApp.keyWindow);
    }];
    DPInstallHiddenStripTab();
    DPInstallStandIn();
    DPInstallPress();
}

DP_PATCH(DPCommandBarHideTab) {
    .key = @"commandBarHideTab",
    .defaultOn = YES,
    .order = 93,
    .title = @"Hide New Tab Until Opened",
    .detail = @"Keep the new tab out of the sidebar and the tab bar while the command bar is open, like Arc. The New Tab button shows as selected instead, and clicking it again closes the bar. The tab shows once you choose a result.",
    .symbol = @"eye.slash.fill",
    .tint = @"systemOrangeColor",
    .requires = @"commandBar",
    .section = @"Tabs",
    .classes = DPClasses(DPDiaTabListCollection, DPDiaTabListLayout, DPDiaTabStripTabs, DPDiaTabView, DPDiaTabContentView),
    .install = DPInstallHideTab,
    .apply = DPApplyHideTab,
    .verify = DPVerifyHideTab,
};
