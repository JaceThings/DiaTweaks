#import "LittleDia.h"

extern BOOL DPLittleLaunched;

// Links that launch Dia open as usual, since its windows are still being restored.
static BOOL DPWantsLittleDia(NSURL *url) {
    return DPLittleDia.on && DPLittleLaunched && [@[@"http", @"https"] containsObject:url.scheme.lowercaseString];
}

// Dia takes links from other apps in its own Apple Event handler rather than application:openURLs:.
static void DPOpenURLEvent_handle(id self, SEL _cmd, NSAppleEventDescriptor *event, NSAppleEventDescriptor *reply) {
    NSString *text = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    NSURL *url = text ? [NSURL URLWithString:text] : nil;
    if (event.eventClass != kInternetEventClass || event.eventID != kAEGetURL || !DPWantsLittleDia(url)) {
        DPCallOriginal(DPOpenURLEvent_handle, self, event, reply);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        DPOpenLittleDia(url, YES, ^{ DPCallOriginal(DPOpenURLEvent_handle, self, event, reply); });
    });
}

// Dia answers a navigation with where it should open (1 this tab, 2 a new tab in front, 3 a background tab), or 0 to drop it.
static const NSInteger DPDropNavigation = 0, DPCurrentTab = 1, DPNewForegroundTab = 2;

// The registrable part of a host, close enough to tell sites apart: "docs.google.com" and "google.com" match, as do "bbc.co.uk" hosts.
static NSString *DPSite(NSString *host) {
    NSArray<NSString *> *labels = [host.lowercaseString componentsSeparatedByString:@"."];
    NSUInteger keep = labels.count >= 3 && labels.lastObject.length == 2 && labels[labels.count - 2].length <= 3 ? 3 : 2;
    keep = MIN(keep, labels.count);
    return [[labels subarrayWithRange:NSMakeRange(labels.count - keep, keep)] componentsJoinedByString:@"."];
}

// A link to another site that would open a new tab goes to Little Dia instead, like Little Arc.
// Inside Little Dia it replaces the page, so the window keeps a single tab.
static NSInteger DPWebContent_decidePolicy(id self, SEL _cmd, id webContents, id action) {
    NSInteger disposition = DPCallOriginal(DPWebContent_decidePolicy, self, webContents, action);
    if (!DPLittleDia.on || disposition != DPNewForegroundTab) return disposition;
    NSURL *url = [action valueForKey:@"url"];
    id page = [webContents valueForKey:@"url"];
    if ([page isKindOfClass:NSString.class]) page = [NSURL URLWithString:page];
    if (![url isKindOfClass:NSURL.class] || ![page isKindOfClass:NSURL.class] || ![@[@"http", @"https"] containsObject:url.scheme.lowercaseString]
        || !url.host || !((NSURL *)page).host || [DPSite(url.host) isEqualToString:DPSite(((NSURL *)page).host)])
        return disposition;
    if ([DPLittleWindows containsObject:NSApp.keyWindow]) return DPCurrentTab;
    dispatch_async(dispatch_get_main_queue(), ^{
        DPOpenLittleDia(url, YES, ^{
            DPDiaScript([NSString stringWithFormat:@"make new tab at end of tabs of window 1 with properties {URL:%@}", DPQuoted(url.absoluteString)]);
        });
    });
    return DPDropNavigation;
}

void DPInstallLittleLinks(void) {
    DPHook(DPDiaOpenURLEventManager, @selector(handleEvent:withReplyEvent:), (IMP)DPOpenURLEvent_handle);
}

void DPInstallLittleNavigation(void) {
    DPHook(DPDiaWebContent, NSSelectorFromString(@"webContents:decidePolicyForNavigationAction:"), (IMP)DPWebContent_decidePolicy);
}
