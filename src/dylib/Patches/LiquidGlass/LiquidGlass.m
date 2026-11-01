#import "LiquidGlass.h"

static void DPApplyLiquidGlass(DPPatch *patch) { DPRefreshGlassHosts(); }
static NSString *DPVerifyLiquidGlass(DPPatch *patch) { return DPVerifyGlassHosts(patch->on); }

static void DPInstallLiquidGlass(void) {
    DPInstallGlassHosts();
    DPOnLaunch(^{ DPRefreshGlassHosts(); });
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DPRefreshGlassHosts(); }];
}

DP_PATCH(DPLiquidGlass) {
    .key = @"liquidGlass",
    .order = 100,
    .title = @"Liquid Glass",
    .detail = @"Native Liquid Glass in the sidebar. Toolbar and top-tab layouts keep their original appearance. Adapts to light and dark mode and respects Reduce Transparency. Requires macOS 26 or later. Experimental.",
    .symbol = @"square.on.circle",
    .tint = @"systemCyanColor",
    .section = @"Theme",
    .classes = DPClasses("NSGlassEffectView", DPDiaSidebarController),
    .install = DPInstallLiquidGlass,
    .apply = DPApplyLiquidGlass,
    .verify = DPVerifyLiquidGlass,
};
