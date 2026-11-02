#import "HideToolbar.h"

// Stays on while Hide toolbar is off, so ⌃D can bring it back.
extern DPPatch DPToggleToolbarVisibility;
static id DPKeyMonitor;

static BOOL DPIsToggleToolbarKey(NSEvent *event) {
    NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~NSEventModifierFlagCapsLock;
    return flags == NSEventModifierFlagControl && [event.charactersIgnoringModifiers.lowercaseString isEqualToString:@"d"];
}

static void DPInstallToggleToolbar(void) {
    DPKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (DPToggleToolbarVisibility.on && !event.isARepeat && DPIsToggleToolbarKey(event)) {
            DPSetPatch(&DPHideToolbar, !DPHideToolbar.on, YES);
            [NSNotificationCenter.defaultCenter postNotificationName:DPPatchesDidChangeNotification object:nil];
        }
        return event;
    }];
}

static void DPApplyToggleToolbar(DPPatch *patch) {}

static NSString *DPVerifyToggleToolbar(DPPatch *patch) { return DPKeyMonitor ? nil : @"nothing listens for ⌃D"; }

DP_PATCH(DPToggleToolbarVisibility) {
    .key = @"toggleToolbarVisibility",
    .order = 35,
    .title = @"Toggle toolbar visibility",
    .detail = @"Press ⌃D to hide or show the toolbar.",
    .symbol = @"command",
    .tint = @"systemGrayColor",
    .requires = @"hideToolbar",
    .classes = DPClasses(DPDiaContentPane, DPDiaToolbar),
    .install = DPInstallToggleToolbar,
    .apply = DPApplyToggleToolbar,
    .verify = DPVerifyToggleToolbar,
};
