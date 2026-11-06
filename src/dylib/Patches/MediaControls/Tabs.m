#import "MediaControls.h"

// Which window each tab is in. Dia keeps one browser per window that owns its tabs; a tab dragged to another window
// changes browser.
static NSMapTable *DPBrowserByTab, *DPWindowByBrowser;

static void DPOwn(id tab, id browser) {
    if (tab && browser) [DPBrowserByTab setObject:browser forKey:tab];
}

static void DPMB_setWindow(id self, SEL _cmd, NSWindow *window) {
    DPCallOriginal(DPMB_setWindow, self, window);
    if (window) [DPWindowByBrowser setObject:window forKey:self];
}
// Tabs opened from Dia's own UI come from here; the delegate callbacks below see restored tabs and ones a page opens.
static id DPMB_create(id self, SEL _cmd, id params) {
    id tab = DPCallOriginal(DPMB_create, self, params);
    DPOwn(tab, self);
    return tab;
}
static void DPMB_take(id self, SEL _cmd, id tab) {
    DPCallOriginal(DPMB_take, self, tab);
    DPOwn(tab, self);
}
static void DPMB_restored(id self, SEL _cmd, id browser, id tab, id session) {
    DPCallOriginal(DPMB_restored, self, browser, tab, session);
    DPOwn(tab, browser);
}
static void DPMB_created(id self, SEL _cmd, id browser, id tab, BOOL active) {
    DPCallOriginal(DPMB_created, self, browser, tab, active);
    DPOwn(tab, browser);
}

id DPMediaBrowserOf(id tab) { return tab ? [DPBrowserByTab objectForKey:tab] : nil; }

NSWindow *DPMediaWindowOf(id tab) {
    id browser = DPMediaBrowserOf(tab);
    return browser ? [DPWindowByBrowser objectForKey:browser] : nil;
}

// Switching tabs and renaming them change the cards too, but only for tabs with media. A closed tab's media session
// ends first, which Source.m hears.
static void DPTab_setVisibility(id self, SEL _cmd, long visibility) {
    DPCallOriginal(DPTab_setVisibility, self, visibility);
    if (DPMediaHasMedia(self)) DPMediaRefresh(self);
}
static void DPTab_setTitle(id self, SEL _cmd, NSString *title) {
    DPCallOriginal(DPTab_setTitle, self, title);
    if (DPMediaHasMedia(self)) DPMediaRefresh(self);
}

id DPSelectedTab(NSWindow *window) {
    for (id tab in DPMediaTabs())
        if (DPMediaWindowOf(tab) == window && ((long (*)(id, SEL))objc_msgSend)(tab, @selector(visibility)) != 0) return tab;
    return nil;
}

void DPInstallMediaTabs(void) {
    DPBrowserByTab = [NSMapTable weakToWeakObjectsMapTable];
    DPWindowByBrowser = [NSMapTable weakToWeakObjectsMapTable];
    DPHook(DPDiaBrowser, @selector(setWindow:), (IMP)DPMB_setWindow);
    DPHook(DPDiaBrowser, @selector(createWebContents:), (IMP)DPMB_create);
    DPHook(DPDiaBrowser, @selector(takeOwnershipOfWebContents:), (IMP)DPMB_take);
    DPHook(DPDiaBrowserDelegate, @selector(browser:didRestoreWebContents:withSessionId:), (IMP)DPMB_restored);
    DPHook(DPDiaBrowserDelegate, @selector(browser:didCreateNewWebContents:isActive:), (IMP)DPMB_created);
    DPHook(DPDiaWebContents, @selector(setVisibility:), (IMP)DPTab_setVisibility);
    DPHook(DPDiaWebContents, @selector(setTitle:), (IMP)DPTab_setTitle);
}
