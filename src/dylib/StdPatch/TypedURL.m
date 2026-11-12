#import "StdPatch.h"
#import <arpa/inet.h>

// Schemes kept as typed without "//", as Dia's own address bar keeps them. javascript: isn't one: a bar that only
// navigates has nothing to run it on, so it is searched for.
static BOOL DPKeepsScheme(NSString *scheme) {
    return [@[ @"about", @"chrome", @"data", @"file", @"mailto", @"view-source" ] containsObject:scheme];
}

static BOOL DPIsPort(NSString *text) {
    return text.length && text.length <= 5 && text.integerValue <= 65535 &&
           [text rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
}

static BOOL DPIsIPv4(NSArray<NSString *> *labels) {
    if (labels.count != 4) return NO;
    for (NSString *label in labels)
        if (!DPIsPort(label) || label.length > 3 || label.integerValue > 255) return NO;
    return YES;
}

// Whether the last label is a top-level domain. Foundation's link detector is the only list the system offers; it knows .com,
// .io, .ai and the country codes, not every newer one (.dev, .app, .sh), which are then searched for, as Chromium does an
// unknown one. Asked with a made-up first label, so only the ending counts.
static BOOL DPIsTopLevel(NSString *label) {
    static NSDataDetector *links;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ links = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil]; });
    if (!links) return YES;
    NSString *host = [@"foo." stringByAppendingString:label];
    NSTextCheckingResult *match = [links firstMatchInString:host options:0 range:NSMakeRange(0, host.length)];
    return match && NSEqualRanges(match.range, NSMakeRange(0, host.length));
}

static BOOL DPIsHostLabel(NSString *label) {
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *set = [NSCharacterSet.letterCharacterSet mutableCopy];
        [set formUnionWithCharacterSet:NSCharacterSet.decimalDigitCharacterSet];
        [set formUnionWithCharacterSet:NSCharacterSet.nonBaseCharacterSet];
        [set addCharactersInString:@"-_"];
        allowed = set;
    });
    return label.length && ![label hasPrefix:@"-"] && ![label hasSuffix:@"-"] &&
           [label rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

NSURL *DPAddressURL(NSString *typed) {
    NSCharacterSet *space = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *text = [typed stringByTrimmingCharactersInSet:space];
    if (!text.length || [text rangeOfCharacterFromSet:space].location != NSNotFound) return nil;

    // An explicit scheme is kept as typed.
    NSRange colon = [text rangeOfString:@":"];
    NSString *scheme = colon.location == NSNotFound ? @"" : [text substringToIndex:colon.location].lowercaseString;
    NSCharacterSet *schemeLetters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789+.-"];
    if (scheme.length && isalpha([scheme characterAtIndex:0]) && [scheme rangeOfCharacterFromSet:schemeLetters.invertedSet].location == NSNotFound &&
        ![scheme isEqual:@"javascript"] && ([[text substringFromIndex:NSMaxRange(colon)] hasPrefix:@"//"] || DPKeepsScheme(scheme)))
        return [NSURL URLWithString:text];

    // Else a host with a port, a path or a query: what comes before the first / ? or #.
    NSRange end = [text rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
    NSString *authority = end.location == NSNotFound ? text : [text substringToIndex:end.location], *host = authority, *port = nil;
    if ([authority hasPrefix:@"["]) {  // [::1] or [::1]:3000
        NSRange close = [authority rangeOfString:@"]"];
        if (close.location == NSNotFound) return nil;
        NSString *after = [authority substringFromIndex:NSMaxRange(close)];
        struct in6_addr address;
        if (inet_pton(AF_INET6, [authority substringWithRange:NSMakeRange(1, close.location - 1)].UTF8String, &address) != 1) return nil;
        if (after.length && !([after hasPrefix:@":"] && DPIsPort([after substringFromIndex:1]))) return nil;
        return [NSURL URLWithString:[@"http://" stringByAppendingString:text]];
    }
    NSRange portAt = [authority rangeOfString:@":" options:NSBackwardsSearch];
    if (portAt.location != NSNotFound) {
        host = [authority substringToIndex:portAt.location];
        port = [authority substringFromIndex:NSMaxRange(portAt)];
        if (!DPIsPort(port)) return nil;
    }

    // A name with an @ is an email address, and fails the check on its letters.
    NSString *name = host.lowercaseString;
    if ([name hasSuffix:@"."]) name = [name substringToIndex:name.length - 1];
    NSArray<NSString *> *labels = [name componentsSeparatedByString:@"."];
    for (NSString *label in labels) if (!DPIsHostLabel(label)) return nil;

    // This machine or one on its network speaks plain HTTP, as does anything given a port. A name with a top-level domain is
    // a site, tried over HTTPS because nothing here can fall back to HTTP.
    if (DPIsIPv4(labels) || [name isEqual:@"localhost"] || [name hasSuffix:@".localhost"] || port)
        return [NSURL URLWithString:[(port.integerValue == 443 ? @"https://" : @"http://") stringByAppendingString:text]];
    if (labels.count > 1 && ([name hasPrefix:@"www."] || DPIsTopLevel(labels.lastObject))) return [NSURL URLWithString:[@"https://" stringByAppendingString:text]];
    return nil;
}
