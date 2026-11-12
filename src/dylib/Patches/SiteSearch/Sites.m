#import "SiteSearch.h"
#import "Commands/GroupTabs/GroupTabs.h"

@implementation DPSite
@end

static DPSite *DPMakeSite(NSString *host, NSString *name, NSString *url) {
    DPSite *site = [DPSite new];
    site.host = host;
    site.name = name;
    site.url = url;
    return site;
}

// Popular sites with clean search addresses. Chromium's own list, learned from sites' search boxes, fills in the rest.
static NSArray<DPSite *> *DPBuiltInSites(void) {
    static NSArray *sites;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sites = @[
            DPMakeSite(@"amazon.com", @"Amazon", @"https://www.amazon.com/s?k={searchTerms}"),
            DPMakeSite(@"youtube.com", @"YouTube", @"https://www.youtube.com/results?search_query={searchTerms}"),
            DPMakeSite(@"google.com", @"Google", @"https://www.google.com/search?q={searchTerms}"),
            DPMakeSite(@"wikipedia.org", @"Wikipedia", @"https://en.wikipedia.org/w/index.php?search={searchTerms}"),
            DPMakeSite(@"reddit.com", @"Reddit", @"https://www.reddit.com/search/?q={searchTerms}"),
            DPMakeSite(@"github.com", @"GitHub", @"https://github.com/search?q={searchTerms}"),
            DPMakeSite(@"ebay.com", @"eBay", @"https://www.ebay.com/sch/i.html?_nkw={searchTerms}"),
            DPMakeSite(@"etsy.com", @"Etsy", @"https://www.etsy.com/search?q={searchTerms}"),
            DPMakeSite(@"walmart.com", @"Walmart", @"https://www.walmart.com/search?q={searchTerms}"),
            DPMakeSite(@"target.com", @"Target", @"https://www.target.com/s?searchTerm={searchTerms}"),
            DPMakeSite(@"bestbuy.com", @"Best Buy", @"https://www.bestbuy.com/site/searchpage.jsp?st={searchTerms}"),
            DPMakeSite(@"x.com", @"X", @"https://x.com/search?q={searchTerms}"),
            DPMakeSite(@"twitter.com", @"X", @"https://x.com/search?q={searchTerms}"),
            DPMakeSite(@"instagram.com", @"Instagram", @"https://www.instagram.com/explore/search/keyword/?q={searchTerms}"),
            DPMakeSite(@"pinterest.com", @"Pinterest", @"https://www.pinterest.com/search/pins/?q={searchTerms}"),
            DPMakeSite(@"spotify.com", @"Spotify", @"https://open.spotify.com/search/{searchTerms}"),
            DPMakeSite(@"maps.google.com", @"Google Maps", @"https://www.google.com/maps/search/{searchTerms}"),
            DPMakeSite(@"images.google.com", @"Google Images", @"https://www.google.com/search?tbm=isch&q={searchTerms}"),
            DPMakeSite(@"duckduckgo.com", @"DuckDuckGo", @"https://duckduckgo.com/?q={searchTerms}"),
            DPMakeSite(@"bing.com", @"Bing", @"https://www.bing.com/search?q={searchTerms}"),
            DPMakeSite(@"perplexity.ai", @"Perplexity", @"https://www.perplexity.ai/search?q={searchTerms}"),
            DPMakeSite(@"chatgpt.com", @"ChatGPT", @"https://chatgpt.com/?q={searchTerms}"),
            DPMakeSite(@"imdb.com", @"IMDb", @"https://www.imdb.com/find/?q={searchTerms}"),
            DPMakeSite(@"netflix.com", @"Netflix", @"https://www.netflix.com/search?q={searchTerms}"),
            DPMakeSite(@"linkedin.com", @"LinkedIn", @"https://www.linkedin.com/search/results/all/?keywords={searchTerms}"),
            DPMakeSite(@"stackoverflow.com", @"Stack Overflow", @"https://stackoverflow.com/search?q={searchTerms}"),
            DPMakeSite(@"npmjs.com", @"npm", @"https://www.npmjs.com/search?q={searchTerms}"),
            DPMakeSite(@"unsplash.com", @"Unsplash", @"https://unsplash.com/s/photos/{searchTerms}"),
            DPMakeSite(@"dribbble.com", @"Dribbble", @"https://dribbble.com/search/{searchTerms}"),
            DPMakeSite(@"behance.net", @"Behance", @"https://www.behance.net/search/projects?search={searchTerms}"),
            DPMakeSite(@"fonts.google.com", @"Google Fonts", @"https://fonts.google.com/?query={searchTerms}"),
            DPMakeSite(@"apple.com", @"Apple", @"https://www.apple.com/us/search/{searchTerms}"),
        ];
    });
    return sites;
}

// What was typed, as a bare host: no scheme, www., trailing slash or case.
static NSString *DPBareHost(NSString *typed) {
    NSString *text = [typed stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    for (NSString *prefix in @[ @"https://", @"http://", @"www." ]) if ([text hasPrefix:prefix]) text = [text substringFromIndex:prefix.length];
    while ([text hasSuffix:@"/"]) text = [text substringToIndex:text.length - 1];
    return text;
}

static BOOL DPMatches(DPSite *site, NSString *bare) {
    if ([site.host isEqual:bare]) return YES;
    // "amazon" for amazon.com, but not "google" for maps.google.com.
    NSArray<NSString *> *labels = [site.host componentsSeparatedByString:@"."];
    return labels.count == 2 && [labels[0] isEqual:bare];
}

// The sites Chromium learned from search boxes, as Chrome's Tab to Search uses them; the search engines' own come too.
static NSArray<DPSite *> *DPChromiumSites(NSWindow *window) {
    id browser = DPBrowserOfWindow(window.parentWindow ?: window) ?: DPCommandBrowser();
    id context = [browser respondsToSelector:@selector(preferences)] ? browser : [browser respondsToSelector:@selector(context)] ? [(NSObject *)browser valueForKey:@"context"] : nil;
    id preferences = [context respondsToSelector:@selector(preferences)] ? [(NSObject *)context valueForKey:@"preferences"] : nil;
    NSArray *engines = [preferences respondsToSelector:@selector(getSearchEngines)] ? [preferences performSelector:@selector(getSearchEngines)] : nil;
    NSMutableArray *sites = [NSMutableArray new];
    for (NSObject *engine in [engines isKindOfClass:NSArray.class] ? engines : @[]) {
        NSString *keyword = [engine valueForKey:@"keyword"], *name = [engine valueForKey:@"name"], *url = [engine valueForKey:@"url"];
        if (![keyword isKindOfClass:NSString.class] || ![url isKindOfClass:NSString.class] || ![url containsString:@"{searchTerms}"]) continue;
        if ([keyword hasPrefix:@"@"] || ![url hasPrefix:@"http"]) continue;  // @bookmarks and @history open Chromium's own pages.
        NSString *host = DPBareHost(keyword);
        // An auto-added engine is named after its host; the part before the dot reads better.
        if (![name isKindOfClass:NSString.class] || !name.length || [DPBareHost(name) isEqual:host])
            name = [host componentsSeparatedByString:@"."].firstObject.capitalizedString;
        [sites addObject:DPMakeSite(host, name, url)];
    }
    return sites;
}

DPSite *DPSiteFor(NSString *typed, NSWindow *window) {
    NSString *bare = DPBareHost(typed);
    if (!bare.length || [bare rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location != NSNotFound) return nil;
    for (DPSite *site in DPBuiltInSites()) if (DPMatches(site, bare)) return site;
    for (DPSite *site in DPChromiumSites(window)) if (DPMatches(site, bare)) return site;
    return nil;
}

NSURL *DPSiteSearchURL(DPSite *site, NSString *query) {
    if (!query.length) return [NSURL URLWithString:[@"https://" stringByAppendingString:site.host]];
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"&+=#?/"];
    NSString *encoded = [query stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSString *url = [site.url stringByReplacingOccurrencesOfString:@"{searchTerms}" withString:encoded];
    // Chromium's other placeholders, such as {inputEncoding}, mean nothing outside its omnibox. Google's own drop out too.
    NSRegularExpression *rest = [NSRegularExpression regularExpressionWithPattern:@"\\{[^}]*\\}" options:0 error:nil];
    url = [rest stringByReplacingMatchesInString:url options:0 range:NSMakeRange(0, url.length) withTemplate:@""];
    return [NSURL URLWithString:url];
}
