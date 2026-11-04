#import "HomeButton.h"

static NSString *const DPHomePageKey = @"homeButtonPage";

static NSUserDefaults *DPHomeDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return defaults;
}

NSString *DPHomePage(void) { return [DPHomeDefaults() stringForKey:DPHomePageKey] ?: @""; }
void DPSetHomePage(NSString *page) { [DPHomeDefaults() setObject:page forKey:DPHomePageKey]; }

NSURL *DPHomeURL(void) {
    NSString *page = [DPHomePage() stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!page.length) return nil;
    if (![page containsString:@":"]) page = [@"https://" stringByAppendingString:page];
    return [NSURL URLWithString:page];
}

// "Go to apple.com", or the whole address when it has no host, such as a file.
NSString *DPHomeTipText(void) {
    NSURL *url = DPHomeURL();
    if (!url) return @"Choose a home page in Settings › Patches";
    NSString *host = url.host;
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    return [@"Go to " stringByAppendingString:host.length ? host : url.absoluteString];
}

// Through the tab Dia's AppleScript sees, whose URL loads a page when set, like typing it in the address field.
void DPGoHome(NSWindow *window) {
    NSURL *url = DPHomeURL();
    if (!url) return;
    for (id scripted in [(id)NSApp.delegate valueForKey:@"appleScriptWindows"]) {
        if (![[scripted valueForKey:@"windowId"] isEqual:window.identifier]) continue;
        [[scripted valueForKey:@"activeTab"] setValue:url.absoluteString forKey:@"URL"];
        return;
    }
}
