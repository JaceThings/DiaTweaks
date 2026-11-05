#import "Internal.h"

static void DPIntegration_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPIntegration_viewDidMoveToWindow, self);
    if (self.window) DPAttachIntegrationHover(self);
    else DPDetachIntegrationHover(self);
}

static BOOL DPIntegrationHoverInstalled;

void DPInstallIntegrationHover(void) {
    if (DPIntegrationHoverInstalled) return;
    DPIntegrationHoverInstalled = YES;
    DPInstallIntegrationHost();
    DPHook(DPDiaTabView, @selector(viewDidMoveToWindow), (IMP)DPIntegration_viewDidMoveToWindow);
    DPHook(DPDiaPinnedTab, @selector(viewDidMoveToWindow), (IMP)DPIntegration_viewDidMoveToWindow);
}
