#import "Internal.h"
#import "DataInternal.h"
#import <objc/message.h>

DPTabIntegrationPage *DPTabIntegrationPageForTab(DPTabIntegration *integration, id tab) {
    if (!tab) return nil;
    NSWindow *window = DPTabIntegrationTabWindow(tab);
    NSString *url = DPTabIntegrationURLString([tab valueForKey:@"URL"]);
    NSString *origin = DPTabIntegrationOrigin(url);
    if (!window || !origin || !DPTabIntegrationMatchesURL(integration, url)) return nil;
    NSUInteger originTabs = 0, exactTabs = 0;
    BOOL present = NO;
    for (id sibling in DPIntegrationTabsInWindow(window)) {
        id siblingURL = [sibling valueForKey:@"URL"];
        if ([[sibling valueForKey:@"tabId"] isEqual:[tab valueForKey:@"tabId"]]) present = YES;
        if (!DPTabIntegrationMatchesURL(integration, siblingURL)
            || ![origin isEqual:DPTabIntegrationOrigin(siblingURL)]) continue;
        originTabs++;
        if ([url isEqual:DPTabIntegrationURLString(siblingURL)]) exactTabs++;
    }
    if (!present || exactTabs != 1) return nil;
    DPTabIntegrationPage *exact = DPTabIntegrationPageForURL(integration, window, url);
    if (exact) return exact;
    if (originTabs != 1) return nil;
    DPTabIntegrationPage *only = nil;
    for (DPTabIntegrationPage *page in DPTabIntegrationPages(integration, window)) {
        id current = ((id (*)(id, SEL))objc_msgSend)(page.contents, @selector(url));
        if (![origin isEqual:DPTabIntegrationOrigin(current)]) continue;
        if (only) return nil;
        only = page;
    }
    return only;
}
