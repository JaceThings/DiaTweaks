#import "Internal.h"
#import <objc/message.h>

static id DPScriptWindowWithID(NSString *identifier) {
    id delegate = NSApp.delegate;
    NSArray *windows = [delegate respondsToSelector:NSSelectorFromString(@"appleScriptWindows")]
        ? [delegate valueForKey:@"appleScriptWindows"] : nil;
    for (id window in windows)
        if ([[window valueForKey:@"windowId"] isEqual:identifier]) return window;
    return nil;
}

static void DPNavigateAfterSelection(DPTabIntegration *integration, NSString *windowID,
                                     NSString *tabID, NSString *url, NSUInteger attempts) {
    if (!DPTabIntegrationEnabled(integration)) return;
    id window = DPScriptWindowWithID(windowID);
    if (!window) return;
    if ([[[window valueForKey:@"activeTab"] valueForKey:@"tabId"] isEqual:tabID]) {
        for (id target in [window valueForKey:@"appleScriptTabs"]) {
            if (![[target valueForKey:@"tabId"] isEqual:tabID]) continue;
            id currentURL = [target valueForKey:@"URL"];
            if (!DPTabIntegrationMatchesURL(integration, currentURL)
                || DPTabIntegrationForURL(currentURL) != integration
                || !DPTabIntegrationMatchesURL(integration, url)
                || DPTabIntegrationForURL(url) != integration) return;
            [target setValue:url forKey:@"URL"];
            return;
        }
        return;
    }
    if (!attempts) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        DPNavigateAfterSelection(integration, windowID, tabID, url, attempts - 1);
    });
}

void DPTabIntegrationNavigateTab(DPTabIntegration *integration, id tab, NSString *url) {
    id currentURL = [tab valueForKey:@"URL"];
    NSString *destination = DPTabIntegrationURLString(url);
    if (!destination.length || !DPTabIntegrationEnabled(integration)
        || !DPTabIntegrationMatchesURL(integration, currentURL)
        || DPTabIntegrationForURL(currentURL) != integration
        || !DPTabIntegrationMatchesURL(integration, destination)
        || DPTabIntegrationForURL(destination) != integration) return;
    NSWindow *native = DPTabIntegrationTabWindow(tab);
    NSString *windowID = [native.identifier copy];
    NSString *tabID = [[tab valueForKey:@"tabId"] description].copy;
    if (!windowID.length || !tabID.length) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        id window = DPScriptWindowWithID(windowID);
        if (!window) return;
        for (id target in [window valueForKey:@"appleScriptTabs"]) {
            if (![[target valueForKey:@"tabId"] isEqual:tabID]) continue;
            id current = [target valueForKey:@"URL"];
            if (!DPTabIntegrationMatchesURL(integration, current)
                || DPTabIntegrationForURL(current) != integration) return;
            if ([target respondsToSelector:@selector(focus:)])
                ((void (*)(id, SEL, id))objc_msgSend)(target, @selector(focus:), nil);
            DPNavigateAfterSelection(integration, windowID, tabID, destination, 20);
            return;
        }
    });
}
