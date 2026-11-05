#import "DeveloperMode.h"

// Developer mode is per site. Local pages have it on until switched off, and any other site can be saved with Control-D.
// The saved choices are host to BOOL, and only differences from the default are kept.
static NSString *const DPSitesKey = @"developerModeSites";

static NSUserDefaults *DPPrefs(void) {
    static NSUserDefaults *prefs;
    if (!prefs) prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    return prefs;
}

static BOOL DPIsLocal(NSString *host) {
    return [host isEqualToString:@"localhost"] || [host hasSuffix:@".localhost"] || [host hasSuffix:@".test"]
        || [host isEqualToString:@"127.0.0.1"] || [host isEqualToString:@"0.0.0.0"] || [host isEqualToString:@"::1"];
}

// Dia's script windows list the tabs but not their NSWindow, so a window's place from the front pairs the two.
static id DPActiveTab(NSWindow *window) {
    NSMutableArray<NSWindow *> *windows = [NSMutableArray new];
    for (NSWindow *candidate in NSApp.orderedWindows) if (DPIsKind(candidate, DPDiaWindow)) [windows addObject:candidate];
    NSArray *scripts = [[(id)NSApp.delegate valueForKey:@"appleScriptWindows"] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        return [[a valueForKey:@"orderedIndex"] compare:[b valueForKey:@"orderedIndex"]];
    }];
    NSUInteger rank = [windows indexOfObject:window];
    return rank < scripts.count ? [scripts[rank] valueForKey:@"activeTab"] : nil;
}

NSString *DPActiveTabID(NSWindow *window) { return [[DPActiveTab(window) valueForKey:@"tabId"] description]; }

NSWindow *DPFrontBrowserWindow(void) {
    for (NSWindow *window in NSApp.orderedWindows) if (DPIsKind(window, DPDiaWindow)) return window;
    return nil;
}

static NSString *DPHostOfURL(NSString *string) {
    NSURL *url = [NSURL URLWithString:string];
    return [@[@"http", @"https"] containsObject:url.scheme] ? url.host : nil;
}

static NSString *DPHost(NSWindow *window) { return DPHostOfURL([[DPActiveTab(window) valueForKey:@"URL"] description]); }

static BOOL DPShownForHost(NSString *host) {
    NSNumber *saved = host ? [DPPrefs() dictionaryForKey:DPSitesKey][host] : nil;
    return saved ? saved.boolValue : host && DPIsLocal(host);
}

BOOL DPDevModeShown(NSWindow *window) { return DPShownForHost(DPHost(window)); }

NSSet<NSString *> *DPDevTabIDs(void) {
    NSMutableSet<NSString *> *ids = [NSMutableSet new];
    for (id script in [(id)NSApp.delegate valueForKey:@"appleScriptWindows"])
        for (id tab in [script valueForKey:@"appleScriptTabs"])
            if (DPShownForHost(DPHostOfURL([[tab valueForKey:@"URL"] description]))) [ids addObject:[[tab valueForKey:@"tabId"] description]];
    return ids;
}

void DPToggleDevMode(NSWindow *window) {
    NSString *host = DPHost(window);
    if (!host) return NSBeep();
    BOOL on = !DPDevModeShown(window);
    NSMutableDictionary *sites = [[DPPrefs() dictionaryForKey:DPSitesKey] mutableCopy] ?: [NSMutableDictionary new];
    if (on == DPIsLocal(host)) [sites removeObjectForKey:host];
    else sites[host] = @(on);
    [DPPrefs() setObject:sites forKey:DPSitesKey];
    DPRelayoutDevMode(NO);
}

void DPWatchDevMode(void) {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        BOOL pressed = (event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagControl
            && [event.charactersIgnoringModifiers isEqualToString:@"d"];
        // In the address field Control-D deletes forward.
        if (!pressed || !DPDeveloperMode.on || !DPIsKind(event.window, DPDiaWindow) || [event.window.firstResponder isKindOfClass:NSText.class]) return event;
        DPToggleDevMode(event.window);
        return nil;
    }];
    // Dia gives no event for a tab loading another page, so the toolbars are asked again.
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *_) {
        if (DPDeveloperMode.on) DPRelayoutDevMode(YES);
    }];
}
