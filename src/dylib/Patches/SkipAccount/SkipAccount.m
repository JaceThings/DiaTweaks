#import "Startup.h"
#import "Updates/Updates.h"

extern DPPatch DPSkipAccount;
static BOOL gSkipping;

static id DPDefaults_objectForKey(NSUserDefaults *self, SEL _cmd, NSString *key) {
    return [key isEqual:@"hasPresentedOnboardingIntro"] ? @YES : DPCallOriginal(DPDefaults_objectForKey, self, key);
}

static BOOL DPDefaults_boolForKey(NSUserDefaults *self, SEL _cmd, NSString *key) {
    return [key isEqual:@"hasPresentedOnboardingIntro"] ? YES : DPCallOriginal(DPDefaults_boolForKey, self, key);
}

static void DPWaitForBrowser(void) {
    __block NSUInteger polls = 0;
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        void **slot = DPIvar(NSApp.delegate, "controller");
        id controller = slot ? (__bridge id)*slot : nil;
        BOOL restored = [DPSwiftValue(controller, @"hasFinishedRestoringWindows") boolValue];
        if (!restored && ++polls < 120) return;
        [timer invalidate];
        if (!restored) return;
        for (NSWindow *window in NSApp.windows) if (DPIsKind(window, DPDiaWindow)) return;
        // The File item carries the default profile even before any windows have been opened.
        NSMenu *file = [NSApp.mainMenu itemWithTitle:@"File"].submenu;
        for (NSMenuItem *item in file.itemArray) {
            if (![item.title hasPrefix:@"New Window"]) continue;
            [NSApp sendAction:item.action to:item.target from:item];
            break;
        }
    }];
}

static void DPInstallSkipAccount(void) {
    if (!DPSkipAccount.on) return;
    gSkipping = DPSkipAccountStartup();
    if (gSkipping) {
        DPHookClass(NSUserDefaults.class, @selector(objectForKey:), (IMP)DPDefaults_objectForKey);
        DPHookClass(NSUserDefaults.class, @selector(boolForKey:), (IMP)DPDefaults_boolForKey);
        DPSkipAccountMenus();
        DPSkipAccountSettings();
        DPOnLaunch(^{ DPWaitForBrowser(); });
        return;
    }
    DPSkipAccount.unavailable = YES;
    DPSkipAccount.on = NO;
    NSLog(@"DiaPatches: Skip Account doesn't know this Dia's startup code, so it stays off");
}

static void DPApplySkipAccount(DPPatch *patch) {
    if (patch->on == gSkipping || patch->on != DPSavedOn(patch)) return;
    NSAlert *alert = [NSAlert new];
    alert.messageText = patch->on ? @"Relaunch Dia to skip account sign-in" : @"Relaunch Dia to use account sign-in";
    [alert addButtonWithTitle:@"Relaunch"];
    [alert addButtonWithTitle:@"Later"];
    if ([alert runModal] == NSAlertFirstButtonReturn) DPHandOffAndQuit(@[ @"apply" ]);
}

static NSString *DPVerifySkipAccount(DPPatch *patch) {
    if (!gSkipping || !patch->on) return nil;  // Startup changes need separate launches, not the self-test's unsaved toggles.
    for (NSMenuItem *item in NSApp.mainMenu.itemArray.firstObject.submenu.itemArray)
        if ([item.title hasPrefix:@"Sign In"] && !item.hidden) return @"sign-in menu item is visible";
    NSString *settings = DPSkipVerifyAccountSettings();
    if (settings) return settings;
    return DPFindViews(DPDiaContentPane).count ? nil : @"no browser page opened after skipping sign-in";
}

DP_PATCH(DPSkipAccount) {
    .key = @"skipAccount",
    .order = 120,
    .title = @"Skip Account",
    .detail = @"Open Dia without signing in or creating a Dia account. Relaunch to apply. Account services still need an account. Use Turn Off AI too for plain browsing. May need an update after some Dia releases.",
    .symbol = @"person.crop.circle.badge.minus person.crop.circle",
    .tint = @"systemBrownColor",
    .section = @"Window",
    .classes = DPClasses(DPDiaAppDelegate, DPSkipAccountHeader),
    .install = DPInstallSkipAccount,
    .apply = DPApplySkipAccount,
    .verify = DPVerifySkipAccount,
};
