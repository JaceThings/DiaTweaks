#import "GroupTabs.h"

// Spellings a capital gets wrong. Ordinary names (Reddit, Google) need nothing here.
static NSString *DPBrandSpelling(NSString *label) {
    static NSDictionary<NSString *, NSString *> *brands;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        brands = @{@"youtube": @"YouTube", @"github": @"GitHub", @"icloud": @"iCloud", @"linkedin": @"LinkedIn",
                   @"paypal": @"PayPal", @"tiktok": @"TikTok", @"openai": @"OpenAI", @"chatgpt": @"ChatGPT",
                   @"ebay": @"eBay", @"imdb": @"IMDb", @"whatsapp": @"WhatsApp"};
    });
    return brands[label];
}

static NSString *DPCapitalise(NSString *label) {
    NSString *brand = DPBrandSpelling(label);
    if (brand) return brand;
    if (!label.length) return label;
    NSString *first = [[label substringToIndex:1] uppercaseString];
    return [first stringByAppendingString:[label substringFromIndex:1]];
}

// name.tld becomes the capitalised name (reddit.com -> Reddit). Further labels stay, so docs.github.com is not
// also titled GitHub. Only the last label is dropped.
NSString *DPGroupTitle(NSString *domain) {
    if (!domain.length) return domain;
    NSArray<NSString *> *labels = [domain componentsSeparatedByString:@"."];
    if (labels.count >= 2) labels = [labels subarrayWithRange:NSMakeRange(0, labels.count - 1)];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *label in labels) if (label.length) [parts addObject:DPCapitalise(label)];
    return parts.count ? [parts componentsJoinedByString:@" "] : domain;
}
