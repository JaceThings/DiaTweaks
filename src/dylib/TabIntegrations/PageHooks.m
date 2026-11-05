#import "PageHooks.h"

static BOOL DPIntegrationPageHooksInstalled;

static id DPIntegration_createWebContents(id self, SEL _cmd, id params) {
    id contents = DPCallOriginal(DPIntegration_createWebContents, self, params);
    DPRememberIntegrationPage(contents, self);
    return contents;
}

static void DPIntegration_setWindow(id self, SEL _cmd, NSWindow *window) {
    DPCallOriginal(DPIntegration_setWindow, self, window);
    DPIntegrationSetBrowserWindow(self, window);
}

static void DPIntegration_restore(id self, SEL _cmd, id browser, id contents, id session) {
    DPCallOriginal(DPIntegration_restore, self, browser, contents, session);
    DPRememberIntegrationPage(contents, browser);
}

static void DPIntegration_create(id self, SEL _cmd, id browser, id contents, BOOL active) {
    DPCallOriginal(DPIntegration_create, self, browser, contents, active);
    DPRememberIntegrationPage(contents, browser);
}

static void DPIntegration_takeOwnership(id self, SEL _cmd, id contents) {
    DPCallOriginal(DPIntegration_takeOwnership, self, contents);
    DPRememberIntegrationPage(contents, self);
}

void DPInstallIntegrationPageHooks(void) {
    if (DPIntegrationPageHooksInstalled) return;
    DPIntegrationPageHooksInstalled = YES;
    DPHook(DPDiaBrowser, @selector(createWebContents:), (IMP)DPIntegration_createWebContents);
    DPHook(DPDiaBrowser, @selector(setWindow:), (IMP)DPIntegration_setWindow);
    DPHook(DPDiaBrowser, @selector(takeOwnershipOfWebContents:), (IMP)DPIntegration_takeOwnership);
    DPHook(DPDiaBrowserDelegate, @selector(browser:didRestoreWebContents:withSessionId:), (IMP)DPIntegration_restore);
    DPHook(DPDiaBrowserDelegate, @selector(browser:didCreateNewWebContents:isActive:), (IMP)DPIntegration_create);
}
