#import "StdPatch/StdPatch.h"

extern DPPatch DPSiteSearch;

// A site that can be searched from the command bar: `host` as typed ("amazon.com"), `name` as shown ("Amazon"), and
// `url` with {searchTerms} where the query goes.
@interface DPSite : NSObject
@property(copy) NSString *host, *name, *url;
@end

DPSite *DPSiteFor(NSString *typed, NSWindow *window);  // nil if what was typed isn't a site to search.
NSURL *DPSiteSearchURL(DPSite *site, NSString *query);  // The site itself for an empty query.
void DPShowChip(NSTextView *text, DPSite *site);  // "Search Amazon" in the field, or none for nil.
void DPSetPlaceholder(NSTextView *text, DPSite *site);  // "Search Amazon" where the field says what to type, or Dia's own for nil.
void DPShowReturnTarget(NSTextView *text, DPSite *site);  // The Return button says the site.
