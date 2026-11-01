#import "Patches/Peek/Peek.h"

// Arc's Peek: Shift-click a link and it opens in a card over the page you're on, then becomes a tab or a split view
// pane only if you expand or split it. Dispositions are ArcCore's own ArcWebContentsNavigationDisposition, numbered
// differently from Chromium's: 4 there is picture-in-picture.
enum { DPIgnoreAction = 0, DPCurrentTab = 1, DPForegroundTab = 2, DPBackgroundTab = 3, DPNewWindow = 5, DPPopup = 6 };

// ArcCore reports a Shift-click as a popup; new tabs and windows count too.
static BOOL DPPeekWanted(NSInteger disposition) {
    BOOL elsewhere = disposition == DPForegroundTab || disposition == DPBackgroundTab || disposition == DPPopup || disposition == DPNewWindow;
    return DPPeek.on && elsewhere && (NSEvent.modifierFlags & NSEventModifierFlagShift);
}

// target="_blank" links and window.open arrive here with a page already made. Peek turns it down and makes its own.
static void DPWebContent_didCreate(id self, SEL _cmd, id webContents, id newWebContent, NSURL *url, NSInteger disposition) {
    if (!DPPeekWanted(disposition) || !(DPPeekShows(webContents) || DPPeekCanOpen(webContents)))
        return (void)DPCallOriginal(DPWebContent_didCreate, self, webContents, newWebContent, url, disposition);
    DPCallOriginal(DPWebContent_didCreate, self, webContents, newWebContent, url, (NSInteger)DPIgnoreAction);
    // A link opened from inside a Peek loads in that Peek, as in Arc.
    if (DPPeekShows(webContents)) return DPPeekLoad(webContents, url);
    NSWindow *window = NSApp.keyWindow;
    NSPoint origin = NSEvent.mouseLocation;
    dispatch_async(dispatch_get_main_queue(), ^{ DPPeekOpen(window, url, origin, self, webContents); });
}

// Plain links that Chromium wants anywhere but the current tab are asked about here first; Dia answers with the
// disposition to open them with.
static NSInteger DPWebContent_decidePolicy(id self, SEL _cmd, id webContents, id action) {
    if (!DPPeekWanted([[action valueForKey:@"navigationDisposition"] integerValue]))
        return DPCallOriginal(DPWebContent_decidePolicy, self, webContents, action);
    if (DPPeekShows(webContents)) return DPCurrentTab;
    if (!DPPeekCanOpen(webContents)) return DPCallOriginal(DPWebContent_decidePolicy, self, webContents, action);
    NSWindow *window = NSApp.keyWindow;
    NSPoint origin = NSEvent.mouseLocation;
    NSURL *url = [action valueForKey:@"url"];
    dispatch_async(dispatch_get_main_queue(), ^{ DPPeekOpen(window, url, origin, self, webContents); });
    return DPIgnoreAction;
}

static void DPInstallPeek(void) {
    DPPeekInstallPages();
    DPOnLaunch(^{
        // Dia's Swift classes resolve only once its runtime is up.
        DPHook(DPDiaWebContent, @selector(webContents:didCreateNewWebContent:targetURL:disposition:), (IMP)DPWebContent_didCreate);
        DPHook(DPDiaWebContent, @selector(webContents:decidePolicyForNavigationAction:), (IMP)DPWebContent_decidePolicy);
    });
}

// Nothing shows until a Shift-click, so it checks the link hooks are the ones answering.
static NSString *DPVerifyPeek(DPPatch *patch) {
    Class delegate = objc_getClass(DPDiaWebContent);
    if (class_getMethodImplementation(delegate, @selector(webContents:decidePolicyForNavigationAction:)) != (IMP)DPWebContent_decidePolicy)
        return @"link clicks don't reach Peek";
    if (class_getMethodImplementation(delegate, @selector(webContents:didCreateNewWebContent:targetURL:disposition:)) != (IMP)DPWebContent_didCreate)
        return @"new windows don't reach Peek";
    return nil;
}

DP_PATCH(DPPeek) {
    .key = @"peek",
    .order = 104,
    .title = @"Peek on Shift-click",
    .detail = @"Shift-click a link to preview it in a card over the page, like Arc. Click outside, press Escape or ⌘W to close it, ⌘O to open it as a tab, or use the buttons beside it.",
    .symbol = @"eye.fill",
    .tint = @"systemMintColor",
    .section = @"Links",
    .classes = DPClasses(DPDiaBrowserContext, DPDiaWebContents, DPDiaWebContentsConfiguration, DPDiaContentPane),
    .install = DPInstallPeek,
    .verify = DPVerifyPeek,
};
