#import "DeveloperMode.h"

// Arc's developer mode put a striped banner and shortcuts to the inspector, console and network panels on local sites.
// Dia keeps those panels in its Developer menu, so the buttons send the same actions. Control-D turns it on or off for
// the current site; localhost has it on by default.

static NSMenuItem *DPItemWithKey(NSMenu *menu, NSString *key, NSEventModifierFlags mask) {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.keyEquivalent isEqualToString:key] && item.keyEquivalentModifierMask == mask) return item;
        NSMenuItem *found = DPItemWithKey(item.submenu, key, mask);
        if (found) return found;
    }
    return nil;
}

// Dia's "Force Refresh the Page", found by its Command-Shift-R rather than its title.
static void DPHardReload(void) {
    NSMenuItem *item = DPItemWithKey(NSApp.mainMenu, @"r", NSEventModifierFlagCommand | NSEventModifierFlagShift);
    [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
}

static DPDevButton *DPPanelButton(NSString *symbol, NSString *label, DPDevPanel panel) {
    DPDevButton *button = [DPDevButton buttonWithSymbol:symbol label:label action:^(NSWindow *window) {
        DPToggleDevPanel(panel, window);
        dispatch_async(dispatch_get_main_queue(), ^{ DPRelayoutDevMode(YES); });
    }];
    button.panel = panel;
    return button;
}

NSArray<DPDevButton *> *DPMakeDevButtons(void) {
    return @[
        [DPDevButton buttonWithSymbol:@"arrow.clockwise.circle" label:@"Hard reload" action:^(NSWindow *_) { DPHardReload(); }],
        DPPanelButton(@"cursorarrow.rays", @"Inspect element", DPPanelInspect),
        DPPanelButton(@"terminal", @"JavaScript console", DPPanelConsole),
        DPPanelButton(@"network", @"Network", DPPanelNetwork),
    ];
}

static void DPBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPBar_layout, self);
    DPPlaceDevMode(self);
}

static void DPRow_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPRow_layout, self);
    DPPlaceTabBorder(self);
}

static void DPInstallDeveloperMode(void) {
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPBar_layout);
    DPHook(DPDiaTabRow, @selector(layout), (IMP)DPRow_layout);
    DPInstallDevPanels();
    DPOnLaunch(^{ DPWatchDevMode(); });
}

static void DPApplyDeveloperMode(DPPatch *patch) { DPRelayoutDevMode(NO); }

DP_PATCH(DPDeveloperMode) {
    .key = @"developerMode",
    .order = 49,
    .title = @"Developer mode",
    .detail = @"Stripe the toolbar, outline the tabs in hazard stripes and add buttons for the inspector, console, network panel and a hard reload on local sites. Control-D turns it on or off for any site.",
    .symbol = @"hammer",
    .tint = @"systemIndigoColor",
    .section = @"Toolbar Items",
    .classes = DPClasses(DPDiaToolbar, DPDiaAddressField, DPDiaTab, DPDiaTabRow, "ArcWebContentsDevTools"),
    .choice = @"developerModeColor",
    .defaultChoice = @"Indigo",
    .choices = DPColorChoices,
    .install = DPInstallDeveloperMode,
    .apply = DPApplyDeveloperMode,
    .verify = DPVerifyDevMode,
};
