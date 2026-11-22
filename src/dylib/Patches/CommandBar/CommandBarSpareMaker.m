#import "Patches/CommandBar/CommandBarOverlay.h"
#import "Patches/CommandBar/Tabs.h"
#import "Patches/CommandBar/HideTab.h"
#import "Patches/CommandBar/AutoPip.h"

extern DPPatch DPNewTabNextToCurrent, DPCommandBarSpare;
static __weak NSWindow *DPSpareWindow;
static CFTimeInterval DPSpareUntil;
static BOOL DPWanted = YES;
static NSTimer *DPSpareTimer;

void DPWantSpare(void) { DPWanted = YES; }
void DPNotMakingSpare(void) { DPSpareUntil = 0; }

void DPDropUnwantedSpares(void) {
    for (NSWindow *window in NSApp.windows)
        if (DPSpareIn(window) && (!DPSparesOn() || DPHasStrip(window))) DPDropSpare(window);
}

static NSView *DPVisiblePeekIn(NSWindow *window) {
    Class card = NSClassFromString(@"DPPeekCard");
    if (!card) return nil;
    return DPFindView(window.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:card] && !view.isHiddenOrHasHiddenAncestor;
    });
}

// Create a hidden spare only when frontmost, idle, and not full screen (switching tabs exits full screen).
static void DPMakeSpare(void) {
    DPDropUnwantedSpares();
    if (!DPSparesOn()) return DPUpdateSpareTimer();
    NSWindow *window = NSApp.keyWindow;
    if (DPTesting || !NSApp.isActive || NSApp.modalWindow || !window || window.attachedSheet) return;
    if (CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType) < 2 || NSEvent.pressedMouseButtons) return;
    if (window.styleMask & NSWindowStyleMaskFullScreen) return;
    static CFTimeInterval lookedAt;
    DPCommandBarOverlay *spare = DPSpareIn(window);
    if (spare && CACurrentMediaTime() - lookedAt > 3) {
        lookedAt = CACurrentMediaTime();
        if (!DPScriptTab(window, DPTabID(spare.openedTab))) DPDropSpare(window);
    }
    BOOL anySpare = NO;
    for (NSWindow *other in NSApp.windows)
        if (DPSpareIn(other)) { anySpare = YES; break; }
    if (!DPWanted && !anySpare && CACurrentMediaTime() >= DPSpareUntil) DPWanted = YES;
    if (!DPWanted) return;
    if (DPSpareIn(window) || DPGet(window, &DPOverlayKey) || DPHidingATab(window) || DPHasStrip(window) || DPVisiblePeekIn(window)) return;
    id scriptWindow = DPScriptWindow(window);
    if (!scriptWindow) return;
    for (NSWindow *child in window.childWindows) if (child.visible) return;
    id frontTab = DPValueForKey(scriptWindow, @"activeTab");
    NSString *front = DPTabID(frontTab);
    if (!front || [DPSplits(window) containsObject:front] || [DPBlanks(window) containsObject:front] || DPBlankPage(window)) return;
    if (![DPValueForKey(frontTab, @"URL") description].length) return;
    if (!DPIsKind(window.firstResponder, "RenderWidgetHostViewCocoa")) return;
    NSMenuItem *item = DPMenuItemTitled(NSApp.mainMenu, @"New Tab");
    if (!item.action) return;
    DPSpareWindow = window;
    DPSpareUntil = CACurrentMediaTime() + 1;
    DPWanted = NO;
    DPExpectNewTab(window);
    __weak NSResponder *typing = window.firstResponder;
    // sendAction: bypasses menu/shortcut PiP hooks, so hold PiP explicitly.
    DPHoldAutoPip();
    if (![NSApp sendAction:item.action to:item.target from:item]) {
        DPSpareUntil = 0;
        DPStopExpecting();
        return DPWantSpare();
    }
    for (int ms = 0; ms <= 300; ms += 300)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, ms * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            NSView *view = (NSView *)typing, *now = (NSView *)window.firstResponder;
            BOOL typingElsewhere = [now isKindOfClass:NSTextView.class] && !now.isHiddenOrHasHiddenAncestor;
            if (view.window == window && now != view && !typingElsewhere && !DPGet(window, &DPOverlayKey) && !DPVisiblePeekIn(window)) [window makeFirstResponder:view];
        });
}

void DPParkIfSpare(DPCommandBarOverlay *overlay) {
    if (overlay.host != DPSpareWindow || CACurrentMediaTime() >= DPSpareUntil) return;
    DPSpareUntil = 0;
    overlay.hidden = YES;
    if (DPParkSpare(overlay)) return;
    DPCancelCommandBar(overlay);
    DPWantSpare();
}

BOOL DPSparesOn(void) { return DPHiding() && DPCommandBarSpare.on && !DPNewTabNextToCurrent.on; }

void DPUpdateSpareTimer(void) {
    if (DPSparesOn()) {
        if (!DPSpareTimer) DPSpareTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { DPMakeSpare(); }];
    } else {
        [DPSpareTimer invalidate];
        DPSpareTimer = nil;
    }
}

static void DPInstallSpares(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:DPPatchesDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        DPDropUnwantedSpares();
        DPUpdateSpareTimer();
    }];
    DPOnLaunch(^{ DPUpdateSpareTimer(); });
    // Retry at 3 s and 12 s in case session restore is slow; drop unfound IDs on the second pass.
    NSArray *left = [DPSettings() arrayForKey:@"commandBarSpares"];
    for (int delay = 3; left.count && delay <= 12; delay += 9)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ DPCloseLeftSpares(left, delay > 3); });
    // Abandoned bar tabs (quit/crash with the bar open) are tracked separately so they
    // are cleaned even when "Open the Bar Instantly" is off.
    NSArray *leftOpen = [DPSettings() arrayForKey:@"commandBarOpenTabs"];
    for (int delay = 3; leftOpen.count && delay <= 12; delay += 9)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ DPCloseLeftOpenTabs(leftOpen, delay > 3); });
    // Hide restored leftovers as soon as they appear so they never flash in the
    // sidebar; the 3 s / 12 s passes above close them once restore settles.
    if (left.count || leftOpen.count) {
        DPHideLeftTabs();
        int marks[] = { 200, 500, 1000, 2000, 2800, 6000, 9000, 11800 };
        for (size_t i = 0; i < sizeof(marks) / sizeof(*marks); i++) {
            int ms = marks[i];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, ms * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ DPHideLeftTabs(); });
        }
    }
}

static void DPApplySpares(DPPatch *patch) {
    DPDropUnwantedSpares();
    DPUpdateSpareTimer();
}

static NSString *DPVerifySpares(DPPatch *patch) {
    for (NSWindow *window in NSApp.windows)
        if (DPSpareIn(window) && !DPSparesOn()) return @"a spare is still kept with the option off";
    return nil;
}

DP_PATCH(DPCommandBarSpare) {
    .key = @"commandBarSpare",
    .order = 95,
    .title = @"Open the Bar Instantly",
    .detail = @"Keep a new tab ready, hidden, so the command bar opens at once instead of waiting for Dia to make one. Needs Hide New Tab Until Opened and tabs in the sidebar, and isn't used with Open New Tabs Next to Current. Experimental.",
    .symbol = @"bolt.fill",
    .tint = @"systemOrangeColor",
    .requires = @"commandBar",
    .section = @"Tabs",
    .classes = DPClasses(DPDiaNewTabPage, DPDiaTabListCollection, DPDiaTabListLayout),
    .install = DPInstallSpares,
    .apply = DPApplySpares,
    .verify = DPVerifySpares,
};
