#import "Peek.h"

// ArcCore dispositions checked on Dia 1.55.1: 0 ignores navigation, 5 opens a window.
enum { DPPeekIgnore = 0, DPPeekNewWindow = 5, DPPeekLink = 0 };

BOOL DPPeekShouldOpen(NSEvent *event, NSUInteger navigationType, NSInteger policy, NSURL *url) {
    NSEventModifierFlags modifiers = event.modifierFlags &
        (NSEventModifierFlagShift | NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl);
    return policy == DPPeekNewWindow && navigationType == DPPeekLink && modifiers == NSEventModifierFlagShift &&
        (event.type == NSEventTypeLeftMouseDown || event.type == NSEventTypeLeftMouseUp) &&
        ([@"http" isEqualToString:url.scheme.lowercaseString] || [@"https" isEqualToString:url.scheme.lowercaseString]);
}

static NSInteger DPPeek_policy(id self, SEL _cmd, id contents, id action) {
    NSInteger policy = DPCallOriginal(DPPeek_policy, self, contents, action);
    if (DPPeek.on && DPPeekShouldOpen(NSApp.currentEvent, [action navigationType], policy, [action url])) {
        if (!DPPeekOpen(contents, [action url], NSApp.currentEvent.locationInWindow)) NSBeep();
        return DPPeekIgnore;
    }
    DPPeekCloseContents(contents);
    return policy;
}

static void DPApplyPeek(DPPatch *patch) {
    if (!patch->on) DPPeekCloseAll();
}

static void DPInstallPeek(void) {
    if (!DPPeekCheckABI()) {
        DPPeek.unavailable = YES;
        DPPeek.on = NO;
        return;
    }
    DPPeekInstallTracking();
    DPHook(DPPeekWebContent, @selector(webContents:decidePolicyForNavigationAction:), (IMP)DPPeek_policy);
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:nil queue:nil
        usingBlock:^(NSNotification *note) { DPPeekCloseWindow(note.object); }];
    DPOnQuit(^{ DPPeekCloseAll(); });
}

DP_PATCH(DPPeek) {
    .key = @"peek",
    .order = 100,
    .title = @"Peek",
    .detail = @"Shift-click a link to preview it over the current page. Close with Escape, the close button, or a click outside. Experimental.",
    .symbol = @"rectangle.on.rectangle",
    .tint = @"systemBlueColor",
    .section = @"Window",
    .classes = DPClasses(DPDiaBrowser, DPDiaBrowserDelegate, DPPeekWebContent, DPDiaContentPane,
        "ArcWebContents", "ArcWebContentsConfiguration", "ArcWebContentsNavigationController", "ArcNavigationAction"),
    .install = DPInstallPeek,
    .apply = DPApplyPeek,
    .verify = DPPeekVerify,
};
