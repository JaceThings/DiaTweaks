#import "Patches/Peek/Peek.h"

// The status text shows spaces, accents and international hosts as people read them, a click's URL has them escaped: escape both the same way.
NSString *DPPeekLinkKey(NSString *address) {
    for (NSString *scheme in @[ @"https://", @"http://" ])
        if ([address hasPrefix:scheme]) address = [address substringFromIndex:scheme.length];
    NSString *escaped = [NSURL URLWithString:[@"http://" stringByAppendingString:address]].absoluteString;
    if (escaped) address = [escaped substringFromIndex:@"http://".length];
    return [address hasSuffix:@"/"] ? [address substringToIndex:address.length - 1] : address;
}
