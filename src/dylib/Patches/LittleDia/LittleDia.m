#import "LittleDia.h"

static const UInt32 DPLittleHotKeySignature = 0x44506C64;
static const NSTimeInterval DPLeftoverPoll = 0.5;
static const int DPLeftoverAttempts = 20;

NSHashTable<NSWindow *> *DPLittleWindows;
__weak NSWindow *DPLittle;
BOOL DPLittleOpening, DPLittleLaunched;
NSUserDefaults *DPLittleDefaults;
NSString *const DPLittleWindowIDKey = @"littleWindowID";
static EventHotKeyRef DPLittleHotKey;

static OSStatus DPLittleHotKeyPressed(EventHandlerCallRef next, EventRef event, void *data) {
    dispatch_async(dispatch_get_main_queue(), ^{ DPOpenLittleDia(nil, NO, nil); });
    return noErr;
}

// ⌥⌘N, from any app, while the patch is on.
static void DPApplyLittleDia(DPPatch *patch) {
    static BOOL handlerInstalled;
    if (DPLittleDia.on && !DPLittleHotKey) {
        if (!handlerInstalled) {
            EventTypeSpec spec = {kEventClassKeyboard, kEventHotKeyPressed};
            handlerInstalled = InstallApplicationEventHandler(DPLittleHotKeyPressed, 1, &spec, NULL, NULL) == noErr;
        }
        RegisterEventHotKey(kVK_ANSI_N, cmdKey | optionKey, (EventHotKeyID){DPLittleHotKeySignature, 1}, GetApplicationEventTarget(), 0, &DPLittleHotKey);
    } else if (!DPLittleDia.on && DPLittleHotKey) {
        UnregisterEventHotKey(DPLittleHotKey);
        DPLittleHotKey = NULL;
    }
}

// ⌘O moves the page into Dia; ⌘W and Esc put Little Dia away.
static NSEvent *DPLittleKeyDown(NSEvent *event) {
    if (![DPLittleWindows containsObject:event.window]) return event;
    NSEventModifierFlags mods = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~NSEventModifierFlagCapsLock;
    BOOL command = mods == NSEventModifierFlagCommand;
    // Esc still reaches a text field being edited, so it can cancel the edit there.
    BOOL editing = [event.window.firstResponder isKindOfClass:NSText.class];
    if (command && event.keyCode == kVK_ANSI_O) DPMoveToDia(event.window);
    else if ((command && event.keyCode == kVK_ANSI_W) || (!mods && event.keyCode == kVK_Escape && !editing)) DPHideLittle(event.window);
    else return event;
    return nil;
}

// Dia restores windows it was showing when it quit, and isn't always quit in a way that lets Little Dia close
// first, so the last one is looked up by ID and closed once Dia has restored its windows.
static void DPCloseLeftover(void) {
    NSString *leftover = [DPLittleDefaults stringForKey:DPLittleWindowIDKey];
    if (!leftover) return;
    NSString *script = [NSString stringWithFormat:@"if (id of every window) contains %1$@ then\nclose window id %1$@\nreturn true\nend if\nreturn false", DPQuoted(leftover)];
    __block int attempts = 0;
    [NSTimer scheduledTimerWithTimeInterval:DPLeftoverPoll repeats:YES block:^(NSTimer *timer) {
        if (![DPDiaScript(script) booleanValue] && ++attempts < DPLeftoverAttempts) return;
        [timer invalidate];
        if ([[DPLittleDefaults stringForKey:DPLittleWindowIDKey] isEqualToString:leftover]) [DPLittleDefaults removeObjectForKey:DPLittleWindowIDKey];
    }];
}

static void DPInstallLittleDia(void) {
    DPLittleWindows = [NSHashTable weakObjectsHashTable];
    DPLittleDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    DPInstallLittleWindowHooks();
    DPInstallLittleLinks();
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:NSWindowWillCloseNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [DPLittleWindows removeObject:note.object];
    }];
    // Like Peek, Little Dia goes away once you're back in another Dia window. Switching apps leaves it be.
    [center addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSWindow *window = note.object;
        if (window != DPLittle && window.canBecomeMainWindow) DPHideLittle(DPLittle);
    }];
    DPOnLaunch(^{
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) { return DPLittleKeyDown(event); }];
        DPApplyLittleDia(&DPLittleDia);
        DPInstallLittleNavigation();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            DPLittleLaunched = YES;
            DPCloseLeftover();
        });
    });
    DPOnQuit(^{ DPCloseLittleWindows(); });
}

static NSString *DPVerifyLittleDia(DPPatch *patch) {
    if (patch->on != (DPLittleHotKey != NULL)) return patch->on ? @"⌥⌘N isn't registered" : @"⌥⌘N is still registered";
    return nil;
}

DP_PATCH(DPLittleDia) {
    .key = @"littleDia",
    .order = 100,
    .title = @"Little Dia",
    .detail = @"Open links from other apps, and new-tab links to other sites, in a small window. Press ⌥⌘N anywhere for a quick one, ⌘O to move it into Dia, and Esc to dismiss it.",
    .symbol = @"macwindow",
    .tint = @"systemYellowColor",
    .classes = DPClasses(DPDiaOpenURLEventManager),
    .install = DPInstallLittleDia,
    .apply = DPApplyLittleDia,
    .verify = DPVerifyLittleDia,
};
