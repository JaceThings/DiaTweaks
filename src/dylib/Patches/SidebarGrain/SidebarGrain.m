#import "SidebarGrain.h"

static void DPGrainSidebarDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPGrainSidebarDidLayout, self);
    DPTrackGrainHost(self.view);
}

static void DPGrainStripDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPGrainStripDidLayout, self);
    DPTrackGrainHost(self.view);
}

static void DPInstallSidebarGrain(void) {
    DPGrainHosts = [NSHashTable weakObjectsHashTable];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskRightMouseDown handler:^NSEvent *(NSEvent *event) {
        return DPGrainRightClick(event);
    }];
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPGrainSidebarDidLayout);
    DPHook(DPDiaTabStripController, @selector(viewDidLayout), (IMP)DPGrainStripDidLayout);
}

static void DPApplySidebarGrain(DPPatch *patch) { DPRefreshSidebarGrain(); }

DP_PATCH(DPSidebarGrain) {
    .key = @"sidebarGrain",
    .order = 74,
    .title = @"Sidebar Grain",
    .detail = @"Add texture behind sidebar or horizontal tabs. Adjust the grain, softness and scale.",
    .choice = @"sidebarGrainMaterial",
    .defaultChoice = @"sand",
    .choices = DPGrainTextureMenu,
    .symbol = @"circle.dotted",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSidebarController, DPDiaSidebarFooter, DPDiaTabStripController, DPDiaTabStrip),
    .install = DPInstallSidebarGrain,
    .apply = DPApplySidebarGrain,
    .verify = DPVerifyGrainHosts,
    .rows = DPGrainRows,
};
