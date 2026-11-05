#import "GroupTabs.h"

// The registrable domain (eTLD+1): gist.github.com and github.com are both github.com, and news.bbc.co.uk is bbc.co.uk.
// A short rule, not the Public Suffix List. Under a two-letter country code, these second labels count as part of the
// suffix: ac, co, com, edu, go, gob, gov, mil, ne, net, or, org. Everything else keeps the last two labels. That groups
// me.uk, ltd.uk, nhs.uk, k12.wa.us, github.io, blogspot.com and vercel.app too high. An IP address, or a host with
// too few labels to split, is left as it is.

static BOOL DPCountryCode(NSString *label) {
    if (label.length != 2) return NO;
    unichar a = [label characterAtIndex:0], b = [label characterAtIndex:1];
    return a >= 'a' && a <= 'z' && b >= 'a' && b <= 'z';
}

static BOOL DPPublicSecondLevel(NSString *label) {
    static NSString *const labels[] = {@"ac", @"co", @"com", @"edu", @"go", @"gob", @"gov", @"mil", @"ne", @"net", @"or", @"org"};
    for (NSUInteger i = 0; i < sizeof labels / sizeof *labels; i++)
        if ([label isEqualToString:labels[i]]) return YES;
    return NO;
}

static BOOL DPAllDigits(NSString *label) {
    if (!label.length) return NO;
    for (NSUInteger i = 0; i < label.length; i++) {
        unichar c = [label characterAtIndex:i];
        if (c < '0' || c > '9') return NO;
    }
    return YES;
}

NSString *DPRegistrableDomain(NSString *host) {
    if (!host.length) return nil;
    host = host.lowercaseString;
    while ([host hasSuffix:@"."]) host = [host substringToIndex:host.length - 1];
    if (!host.length || [host containsString:@":"]) return host.length ? host : nil;
    NSArray<NSString *> *labels = [host componentsSeparatedByString:@"."];
    BOOL address = labels.count > 0;
    for (NSString *label in labels) {
        if (!label.length) return host;
        address = address && DPAllDigits(label);
    }
    if (address || labels.count < 3) return host;
    BOOL country = DPCountryCode(labels.lastObject) && DPPublicSecondLevel(labels[labels.count - 2]);
    NSUInteger keep = country ? 3 : 2;
    if (labels.count <= keep) return host;
    return [[labels subarrayWithRange:NSMakeRange(labels.count - keep, keep)] componentsJoinedByString:@"."];
}
