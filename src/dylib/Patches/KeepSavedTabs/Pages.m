#import "KeepSavedTabs.h"
#import <objc/message.h>

// Dia's sidebar doesn't know which saved tabs have a page open. A tab is paired with the page showing while it's the only
// selected tab in its window, and the pair is forgotten when that page is closed or discarded.

static NSHashTable *DPPages, *DPClosedPages;
static NSMapTable<NSString *, id> *DPTabPages;
static BOOL DPSyncScheduled;

BOOL DPSavedHasPage(NSView *tab) {
    NSString *tabID = DPSavedTabID(tab);
    id page = tabID ? [DPTabPages objectForKey:tabID] : nil;
    return page && ![DPClosedPages containsObject:page];
}

static BOOL DPShowsIn(id page, NSWindow *window) {
    if ([DPClosedPages containsObject:page] || !((BOOL (*)(id, SEL))objc_msgSend)(page, NSSelectorFromString(@"isInitialized"))) return NO;
    if (((NSInteger (*)(id, SEL))objc_msgSend)(page, @selector(visibility)) != 2) return NO;
    return [((NSView *(*)(id, SEL))objc_msgSend)(page, NSSelectorFromString(@"nativeView")) window] == window;
}

static void DPSyncPages(void) {
    DPSyncScheduled = NO;
    for (NSWindow *window in NSApp.windows) {
        if (!window.visible) continue;
        NSArray<NSView *> *tabs = DPSavedTabsIn(window.contentView);
        NSIndexSet *selected = [tabs indexesOfObjectsPassingTest:^BOOL(NSView *tab, NSUInteger i, BOOL *stop) { return DPSavedIsSelected(tab); }];
        NSMutableArray *shown = [NSMutableArray new];
        for (id page in DPPages.allObjects) if (DPShowsIn(page, window)) [shown addObject:page];
        NSString *tabID = selected.count == 1 ? DPSavedTabID(tabs[selected.firstIndex]) : nil;
        if (tabID && shown.count == 1) [DPTabPages setObject:shown.firstObject forKey:tabID];
        for (NSView *tab in tabs) DPSavedUpdate(tab);
    }
}

static void DPScheduleSync(void) {
    if (DPSyncScheduled) return;
    DPSyncScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 15 / 100), dispatch_get_main_queue(), ^{ DPSyncPages(); });
}

static void DPPage_setVisibility(id self, SEL _cmd, NSInteger visibility) {
    DPCallOriginal(DPPage_setVisibility, self, visibility);
    [DPPages addObject:self];
    DPScheduleSync();
}

// close and discard.
static void DPPage_close(id self, SEL _cmd) {
    [DPClosedPages addObject:self];
    DPCallOriginal(DPPage_close, self);
    DPScheduleSync();
}

static void DPPage_closeWithTiming(id self, SEL _cmd, NSInteger timing) {
    [DPClosedPages addObject:self];
    DPCallOriginal(DPPage_closeWithTiming, self, timing);
    DPScheduleSync();
}

void DPInstallSavedPages(void) {
    DPPages = [NSHashTable weakObjectsHashTable];
    DPClosedPages = [NSHashTable weakObjectsHashTable];
    DPTabPages = [NSMapTable strongToWeakObjectsMapTable];
    DPHook(DPDiaWebContents, @selector(setVisibility:), (IMP)DPPage_setVisibility);
    DPHook(DPDiaWebContents, @selector(close), (IMP)DPPage_close);
    DPHook(DPDiaWebContents, NSSelectorFromString(@"discard"), (IMP)DPPage_close);
    DPHook(DPDiaWebContents, NSSelectorFromString(@"closeWithForegroundCommitTiming:"), (IMP)DPPage_closeWithTiming);
}
