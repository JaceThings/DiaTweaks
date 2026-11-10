#import "DevMode.h"

static NSDictionary *DPDefaultCaptureShortcut(void) {
    return @{ @"keyCode" : @19, @"modifiers" : @(NSEventModifierFlagShift | NSEventModifierFlagCommand), @"key" : @"2" };
}

static void DPInstallDevMode(void) {
    DPInstallPages();
    DPInstallStripes();
    DPInstallToolbar();
    DPInstallTabOutlines();
    DPInstallMenuItems();
    DPInstallSiteMenu();
}

static void DPApplyDevMode(DPPatch *patch) {
    DPUpdateToolbars();
    DPUpdateMenuItems();
}

static NSString *DPVerifyDevMode(DPPatch *patch) { return DPVerifyToolbars(patch) ?: DPVerifyTabOutlines() ?: DPVerifyMenuItems(); }

DP_PATCH(DPDevMode) {
    .key = @"devMode",
    .order = 65,
    .title = @"Developer Mode",
    .detail = @"Stripe the toolbar and add Console, Network and Inspect buttons, and copy a picture of the page framed on a color, black or your wallpaper with ⇧⌘2 or the camera. Turn it on in the Site menu. Localhost is on by default.",
    .symbol = @"hammer.circle.fill hammer.fill",
    .tint = @"systemIndigoColor",
    .section = @"Toolbar",
    .classes = DPClasses(DPDiaWebContents, DPDiaToolbar, DPDiaAddressField, DPDiaContentPane, DPDiaTabView, DPDiaTabShape, DPDiaTabStrip),
    .install = DPInstallDevMode,
    .apply = DPApplyDevMode,
    .verify = DPVerifyDevMode,
    .shortcut = @"portraitCaptureShortcut",
    .defaultShortcut = DPDefaultCaptureShortcut,
};
