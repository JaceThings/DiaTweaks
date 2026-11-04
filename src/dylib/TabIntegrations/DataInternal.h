#import "TabIntegrations.h"

// Canonical HTTPS origin or nil. URL paths/query are intentionally ignored here.
NSString *DPTabIntegrationOrigin(id value);
// Canonical origin strings, or nil if any descriptor entry is malformed/non-origin.
NSArray<NSString *> *DPTabIntegrationCanonicalOrigins(const char *const *origins);
