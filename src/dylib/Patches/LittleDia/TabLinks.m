#import "LittleDia.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import "Patches/Peek/Peek.h"

static NSString *const DPFromAllTabs = @"all", *const DPFromPinnedTabs = @"pinned";

static NSArray *DPList(id object, SEL sel) {
    NSArray *list = [object respondsToSelector:sel] ? DPMsg(object, sel) : nil;
    return [list isKindOfClass:NSArray.class] ? list : @[];
}

// Dia's scripting tabs carry the same id as the page's session. A page not matched by id falls back to its address.
static BOOL DPFromPinnedTab(id page) {
    long long sid = DPSessionOf(page);
    NSString *url = DPText(DPMsg(page, @selector(url)));
    BOOL pinnedHere = NO, openHere = NO;
    for (id window in DPList(NSApp.delegate, @selector(appleScriptWindows)))
        for (id tab in DPList(window, @selector(appleScriptTabs))) {
            BOOL pinned = [tab respondsToSelector:@selector(isPinned)] && DPMsgBool(tab, @selector(isPinned));
            long long tabID = [tab respondsToSelector:@selector(tabId)] ? DPLongID(DPMsg(tab, @selector(tabId))) : 0;
            if (sid > 0 && tabID == sid) return pinned;
            NSString *address = [tab respondsToSelector:@selector(URL)] ? DPText(DPMsg(tab, @selector(URL))) : nil;
            if (!url.length || ![address isEqual:url]) continue;
            if (pinned) pinnedHere = YES;
            else openHere = YES;
        }
    return pinnedHere && !openHere;
}

static BOOL DPInLittleDia(id page) {
    for (NSWindow *window in NSApp.windows)
        if (DPIsLittleDiaWindow(window) && DPLittleDiaPage(window) == page) return YES;
    return NO;
}

static BOOL DPPlainClick(void) {
    NSEventModifierFlags held = NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagControl;
    return !(NSEvent.modifierFlags & held);
}

BOOL DPLittleDiaTakesTabLink(id page, NSURL *url, BOOL leavesPinned) {
    if (!DPLittleDia.on || !DPLittleDiaTabLinks.on || DPPeekGiving || !DPPeekIsWeb(url) || !DPPlainClick() || !DPLittleDiaReady()) return NO;
    if (!page || DPInLittleDia(page) || DPPeekShows(page)) return NO;
    if (!leavesPinned && ![DPChoice(&DPLittleDiaTabLinks) isEqual:DPFromAllTabs] && !DPFromPinnedTab(page)) return NO;
    NSWindow *source = NSApp.keyWindow;  // Where the click was; noted now, as Little Dia becomes key next.
    dispatch_async(dispatch_get_main_queue(), ^{ DPOpenTabLinkInLittleDia(url, source); });  // Not from inside Chromium's callback.
    return YES;
}

static NSMenu *DPTabLinksChoices(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Open Links From"];
    [menu addItemWithTitle:@"Pinned Tabs" action:nil keyEquivalent:@""].representedObject = DPFromPinnedTabs;
    [menu addItemWithTitle:@"All Tabs" action:nil keyEquivalent:@""].representedObject = DPFromAllTabs;
    return menu;
}

// Peek owns the link hooks and asks Little Dia first, so check those are in place rather than adding a second hook.
static NSString *DPVerifyTabLinks(DPPatch *patch) {
    Class delegate = objc_getClass(DPDiaWebContent);
    SEL decide = @selector(webContents:decidePolicyForNavigationAction:);
    SEL created = @selector(webContents:didCreateNewWebContent:targetURL:disposition:);
    if (class_getMethodImplementation(delegate, decide) == DPDiaIMP(delegate, decide)) return @"link clicks don't reach Little Dia";
    if (class_getMethodImplementation(delegate, created) == DPDiaIMP(delegate, created)) return @"new tabs don't reach Little Dia";
    return nil;
}

DP_PATCH(DPLittleDiaTabLinks) {
    .key = @"littleDiaTabLinks",
    .order = 104,
    .title = @"Open Links from Tabs",
    .detail = @"Links that would open a new tab open in Little Dia over the page instead. "
              @"Choose pinned tabs only, including links that leave a pinned tab's site, or every tab. Clicks with Option, Command, Shift or Control held keep their usual meaning.",
    .symbol = @"arrow.up.forward.app arrow.up.right.square",
    .tint = @"systemMintColor",
    .requires = @"littleDia",
    .choice = @"littleDiaTabLinksFrom",
    .defaultChoice = @"pinned",
    .choices = DPTabLinksChoices,
    .classes = DPClasses(DPDiaBrowserContext, DPDiaWebContents, DPDiaWebContentsConfiguration, DPDiaContentPane),
    .verify = DPVerifyTabLinks,
};
