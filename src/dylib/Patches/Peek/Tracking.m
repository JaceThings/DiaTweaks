#import "Peek.h"

static NSMapTable *DPBrowsersByPeekContents;

id DPPeekBrowser(id contents) { return [DPBrowsersByPeekContents objectForKey:contents]; }

static id DPPeek_createContents(id self, SEL _cmd, id configuration) {
    id contents = DPCallOriginal(DPPeek_createContents, self, configuration);
    if (contents) [DPBrowsersByPeekContents setObject:self forKey:contents];
    return contents;
}

static void DPPeek_takeOwnership(id self, SEL _cmd, id contents) {
    DPPeekCloseContents(contents);
    DPCallOriginal(DPPeek_takeOwnership, self, contents);
    if (contents) [DPBrowsersByPeekContents setObject:self forKey:contents];
}

static void DPPeek_didRestore(id self, SEL _cmd, id browser, id contents, id session) {
    DPCallOriginal(DPPeek_didRestore, self, browser, contents, session);
    if (browser && contents) [DPBrowsersByPeekContents setObject:browser forKey:contents];
}

static void DPPeek_didCreate(id self, SEL _cmd, id browser, id contents, BOOL active) {
    DPCallOriginal(DPPeek_didCreate, self, browser, contents, active);
    if (browser && contents) [DPBrowsersByPeekContents setObject:browser forKey:contents];
}

static void DPPeek_detach(id self, SEL _cmd, NSView *host) {
    DPPeekCloseContents(self);
    DPCallOriginal(DPPeek_detach, self, host);
}

void DPPeekInstallTracking(void) {
    DPBrowsersByPeekContents = [NSMapTable weakToWeakObjectsMapTable];
    DPHook(DPDiaBrowser, @selector(createWebContents:), (IMP)DPPeek_createContents);
    DPHook(DPDiaBrowser, @selector(takeOwnershipOfWebContents:), (IMP)DPPeek_takeOwnership);
    DPHook(DPDiaBrowserDelegate, @selector(browser:didRestoreWebContents:withSessionId:), (IMP)DPPeek_didRestore);
    DPHook(DPDiaBrowserDelegate, @selector(browser:didCreateNewWebContents:isActive:), (IMP)DPPeek_didCreate);
    DPHook("ArcWebContents", @selector(detachFromPaneHostView:), (IMP)DPPeek_detach);
}
