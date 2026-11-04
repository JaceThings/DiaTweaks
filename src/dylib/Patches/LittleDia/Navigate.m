#import "LittleDia.h"
#import <objc/message.h>

static id DPNavigation(NSWindow *window) {
    id page = DPLittleDiaPage(window);
    return [page respondsToSelector:@selector(navigationController)] ? ((id (*)(id, SEL))objc_msgSend)(page, @selector(navigationController)) : nil;
}

void DPLittleDiaGo(NSWindow *window, SEL action) {
    id navigation = DPNavigation(window);
    if ([navigation respondsToSelector:action]) ((id (*)(id, SEL))objc_msgSend)(navigation, action);
}

NSString *DPLittleDiaURL(NSWindow *window) {
    NSURL *url = ((id (*)(id, SEL))objc_msgSend)(DPLittleDiaPage(window), @selector(url));
    return [url isKindOfClass:NSURL.class] ? url.absoluteString : @"";
}

// What was typed as an address: anything with a scheme, or a host like example.com or localhost:3000. Else nil: a search.
static NSURL *DPTypedURL(NSString *text) {
    if (!text.length || [text rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location != NSNotFound) return nil;
    NSURL *url = [NSURL URLWithString:text];
    NSString *scheme = url.scheme.lowercaseString;
    if (scheme && ([text containsString:@"://"] || [@[ @"about", @"chrome", @"data", @"mailto" ] containsObject:scheme])) return url;
    if ([text hasPrefix:@"localhost"]) return [NSURL URLWithString:[@"http://" stringByAppendingString:text]];
    if ([text containsString:@"."]) return [NSURL URLWithString:[@"https://" stringByAppendingString:text]];
    return nil;
}

// Searches go through the extension, which uses the profile's search engine, as the address bar would.
void DPLittleDiaNavigate(NSWindow *window, NSString *typed) {
    NSString *text = [typed stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL *url = DPTypedURL(text);
    id navigation = DPNavigation(window);
    if (!url && text.length) DPSendToLittleDia(@{@"action" : @"search", @"text" : text, @"url" : DPLittleDiaURL(window)});
    else if (url && [navigation respondsToSelector:@selector(load:initiatorOrigin:)])
        ((id (*)(id, SEL, NSURL *, id))objc_msgSend)(navigation, @selector(load:initiatorOrigin:), url, nil);
}
