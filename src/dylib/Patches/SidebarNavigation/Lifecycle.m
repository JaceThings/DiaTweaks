#import "SidebarNavigation.h"

static BOOL DPSuspendedNavigation;
static void DPNavigationPrepareQuit(void) {
    if (!DPSidebarNavigationControls.on) return;
    DPSuspendedNavigation = YES;
    DPSetPatch(&DPSidebarNavigationControls, NO, NO);
}
static void DPNavigationCancelQuit(void) {
    if (!DPSuspendedNavigation) return;
    DPSuspendedNavigation = NO;
    DPSetPatch(&DPSidebarNavigationControls, DPSavedOn(&DPSidebarNavigationControls), NO);
}
static void DPNavigationTerminate(NSApplication *self, SEL _cmd, id sender) {
    DPNavigationPrepareQuit();
    DPCallOriginal(DPNavigationTerminate, self, sender);
}
static void DPNavigationReply(NSApplication *self, SEL _cmd, BOOL terminate) {
    if (terminate) DPNavigationPrepareQuit(); else DPNavigationCancelQuit();
    DPCallOriginal(DPNavigationReply, self, terminate);
}
static NSApplicationTerminateReply DPNavigationShouldTerminate(id self, SEL _cmd, NSApplication *app) {
    NSApplicationTerminateReply reply = DPCallOriginal(DPNavigationShouldTerminate, self, app);
    if (reply == NSTerminateCancel) DPNavigationCancelQuit();
    else if (reply == NSTerminateNow) DPNavigationPrepareQuit();
    return reply;
}
static BOOL DPNavigationSendAction(NSApplication *self, SEL _cmd, SEL action, id target, id sender) {
    if ([sender isKindOfClass:NSButton.class] && [[sender title] isEqual:@"Quit"] && [sender window].sheetParent)
        DPNavigationPrepareQuit();
    return DPCallOriginal(DPNavigationSendAction, self, action, target, sender);
}
void DPInstallSidebarNavigationLifecycle(void) {
    DPHookClass(NSApp.class, @selector(terminate:), (IMP)DPNavigationTerminate);
    DPHookClass(NSApp.class, @selector(replyToApplicationShouldTerminate:), (IMP)DPNavigationReply);
    DPHookClass(NSApp.delegate.class, @selector(applicationShouldTerminate:), (IMP)DPNavigationShouldTerminate);
    DPHookClass(NSApp.class, @selector(sendAction:to:from:), (IMP)DPNavigationSendAction);
}
