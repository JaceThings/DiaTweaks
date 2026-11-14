#import "DevMode.h"

static NSMenuItem *DPToggleItem, *DPCaptureItem;

static void DPToggleFrontSite(void) {
    NSString *host = DPHostOf(DPFrontPage());
    if (!host) return NSBeep();
    DPSetDevModeOn(host, !DPDevModeOn(host));
}

static void DPCaptureFrontPage(void) {
    id page = DPFrontPage();
    if (!page) return NSBeep();
    DPCapturePortrait(page);
}

static NSMenu *DPDeveloperMenu(void) {
    NSMenu *view = [NSApp.mainMenu itemWithTitle:@"View"].submenu;
    return [view itemWithTitle:@"Developer"].submenu ?: view;
}

void DPUpdateMenuItems(void) {
    NSMenu *menu = DPDeveloperMenu();
    for (NSMenuItem *item in @[ DPToggleItem, DPCaptureItem ])
        if (menu && [menu indexOfItem:item] < 0) [menu addItem:item];
    DPToggleItem.hidden = !DPDevMode.on;
    DPCaptureItem.hidden = !DPDevMode.on;
}

NSString *DPVerifyMenuItems(void) {
    if (DPToggleItem.hidden == DPDevMode.on || DPCaptureItem.hidden == DPDevMode.on) return @"View > Developer doesn't match Developer Mode";
    return nil;
}

void DPInstallMenuItems(void) {
    DPToggleItem = DPMenuItem(@"Toggle Developer Mode", ^{ DPToggleFrontSite(); });
    DPCaptureItem = DPMenuItem(@"Capture in Portrait Mode", ^{ DPCaptureFrontPage(); });
    DPOnLaunch(^{ DPUpdateMenuItems(); });
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (!DPDevMode.on || !DPShortcutMatches(event, &DPDevMode) || !DPFrontPage()) return event;
        if (!event.isARepeat) DPCaptureFrontPage();
        return nil;
    }];
}
