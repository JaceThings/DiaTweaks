#import "GroupTabs.h"

// Spellings a capital gets wrong. Ordinary names (Reddit, Google) need nothing here.
static NSString *DPBrandSpelling(NSString *label) {
    static NSDictionary<NSString *, NSString *> *brands;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        brands = @{@"youtube": @"YouTube", @"github": @"GitHub", @"icloud": @"iCloud", @"linkedin": @"LinkedIn",
                   @"paypal": @"PayPal", @"tiktok": @"TikTok", @"openai": @"OpenAI", @"chatgpt": @"ChatGPT",
                   @"ebay": @"eBay", @"imdb": @"IMDb", @"whatsapp": @"WhatsApp", @"bbc": @"BBC", @"cnn": @"CNN", @"nytimes": @"NYTimes"};
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

// The site's name: reddit.com and old.reddit.com are Reddit, and bbc.co.uk is BBC. An address keeps the host.
NSString *DPGroupTitle(NSString *domain) {
    NSArray<NSString *> *labels = [DPRegistrableDomain(domain) componentsSeparatedByString:@"."];
    if (labels.count < 2 || [labels.lastObject rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location == NSNotFound) return domain;
    return DPCapitalise(labels.firstObject);
}
