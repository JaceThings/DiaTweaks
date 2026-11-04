#import "KeepSavedTabs.h"

static void DPApplyKeepSavedTabs(DPPatch *patch) {
    for (NSView *tab in DPFindViews(DPDiaTabView)) DPSavedUpdate(tab);
}

// Off, no tab shows "–". On, the saved tab you're on shows "–" while its page fills the window.
static NSString *DPVerifyKeepSavedTabs(DPPatch *patch) {
    for (NSView *tab in DPFindViews(DPDiaTabView)) {
        if (tab.hiddenOrHasHiddenAncestor) continue;
        NSButton *close = DPSavedCloseButton(tab);
        BOOL dash = [close.image.accessibilityDescription isEqualToString:@"Close page"];
        if (!patch->on && dash) return @"a tab still shows –";
        if (patch->on && close && !dash && DPSavedIsSelected(tab) && DPSavedKeepsTab(tab) && DPSavedPanes(tab.window) == 1)
            return @"the saved tab you're on shows ✕";
    }
    return nil;
}

static void DPInstallKeepSavedTabs(void) {
    DPInstallSavedClose();
    DPInstallSavedCommand();
    DPInstallSavedPages();
    DPInstallSavedStyle();
}

DP_PATCH(DPKeepSavedTabs) {
    .key = @"keepSavedTabs",
    .order = 85,
    .title = @"Keep Saved Tabs When Closing",
    .detail = @"On tabs above the separator, – or ⌘W closes just the page and keeps the tab. Remove them with the right-click menu. Live folders keep ✕.",
    .symbol = @"pin.fill",
    .tint = @"systemGreenColor",
    .section = @"Tabs & Downloads",
    .classes = DPClasses(DPDiaTabView, DPDiaTabListSeparator, DPDiaTabGroupCell, DPDiaHoverableButton, DPDiaWindowController, DPDiaWebContents),
    .install = DPInstallKeepSavedTabs,
    .apply = DPApplyKeepSavedTabs,
    .verify = DPVerifyKeepSavedTabs,
};
