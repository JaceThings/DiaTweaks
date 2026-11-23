#import "Patches/DeleteProfileMenu/DeleteProfileMenu.h"

// What hiding Settings changed, so it can be put back. Dia reuses the window, so none of it may stay.
static char DPHiddenKey;

// Settings, if Dia has made it. With visibleOnly, only if it's on screen or in the Dock.
NSWindow *DPSettingsWindow(BOOL visibleOnly) {
    for (NSWindow *window in NSApp.windows)
        if (DPIsKind(window, DPDiaSettingsWindow) && (!visibleOnly || window.isVisible || window.isMiniaturized)) return window;
    return nil;
}

BOOL DPSettingsHidden(NSWindow *settings) { return DPGet(settings, &DPHiddenKey) != nil; }

void DPHideSettings(NSWindow *settings) {
    if (!settings || DPSettingsHidden(settings)) return;
    DPSet(settings, &DPHiddenKey, @(settings.animationBehavior));
    settings.animationBehavior = NSWindowAnimationBehaviorNone;  // No open animation to flash.
    settings.alphaValue = 0;
    settings.ignoresMouseEvents = YES;
}

// Puts back what hiding changed, if it still holds what was set.
void DPShowSettings(NSWindow *settings) {
    NSNumber *behavior = DPGet(settings, &DPHiddenKey);
    if (!behavior) return;
    DPSet(settings, &DPHiddenKey, nil);
    if (settings.animationBehavior == NSWindowAnimationBehaviorNone) settings.animationBehavior = behavior.integerValue;
    if (settings.alphaValue == 0) settings.alphaValue = 1;
    settings.ignoresMouseEvents = NO;
}
