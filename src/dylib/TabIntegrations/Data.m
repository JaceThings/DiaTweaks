#import "DataInternal.h"

NSString *DPTabIntegrationURLString(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    return [value isKindOfClass:NSURL.class] ? [value absoluteString] : nil;
}

static NSURLComponents *DPTabIntegrationComponents(id value) {
    NSString *string = DPTabIntegrationURLString(value);
    NSURLComponents *components = string ? [NSURLComponents componentsWithString:string] : nil;
    if (![components.scheme.lowercaseString isEqual:@"https"] || !components.host.length || components.user.length || components.password.length) return nil;
    if (!components.URL) return nil;
    return components;
}

static NSInteger DPTabIntegrationPort(NSURLComponents *components) {
    return components.port ? components.port.integerValue : 443;
}

NSString *DPTabIntegrationOrigin(id value) {
    NSURLComponents *components = DPTabIntegrationComponents(value);
    if (!components) return nil;
    NSInteger port = DPTabIntegrationPort(components);
    if (port < 1 || port > 65535) return nil;
    NSURLComponents *origin = [components copy];
    origin.scheme = @"https";
    origin.host = components.host.lowercaseString;
    origin.path = @"";
    origin.query = nil;
    origin.fragment = nil;
    if (port == 443) origin.port = nil;
    return origin.host.length ? origin.string : nil;
}

NSArray<NSString *> *DPTabIntegrationCanonicalOrigins(const char *const *origins) {
    if (!origins || !*origins) return nil;
    NSMutableOrderedSet<NSString *> *canonical = [NSMutableOrderedSet new];
    for (const char *const *entry = origins; *entry; entry++) {
        NSString *string = [NSString stringWithUTF8String:*entry];
        if (!string) return nil;
        NSURLComponents *components = [NSURLComponents componentsWithString:string];
        if (!components || !components.URL || (components.path.length && ![components.path isEqual:@"/"])
            || components.query.length || components.fragment.length || components.user.length || components.password.length) return nil;
        NSString *origin = DPTabIntegrationOrigin(string);
        if (!origin) return nil;
        [canonical addObject:origin];
    }
    return canonical.array;
}

BOOL DPTabIntegrationAllowsURL(id value, const char *const *origins) {
    NSString *origin = DPTabIntegrationOrigin(value);
    return origin && [DPTabIntegrationCanonicalOrigins(origins) containsObject:origin];
}

BOOL DPTabIntegrationMatchesURL(DPTabIntegration *integration, id value) {
    NSString *url = DPTabIntegrationURLString(value);
    return integration && DPTabIntegrationAllowsURL(value, integration->origins)
        && (!integration->matchesURL || integration->matchesURL(url));
}

NSDictionary *DPTabIntegrationDecode(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length > 256 * 1024) return nil;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    if (!data || data.length > 256 * 1024) return nil;
    id decoded = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
    // Some WebKit bridges JSON-encode the JavaScript string result a second time.
    if ([decoded isKindOfClass:NSString.class]) {
        data = [decoded dataUsingEncoding:NSUTF8StringEncoding];
        decoded = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil] : nil;
    }
    return [decoded isKindOfClass:NSDictionary.class] ? decoded : nil;
}
