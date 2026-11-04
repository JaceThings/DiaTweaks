#import "Internal.h"
#import "DataInternal.h"
#import "Backend.h"

static NSMutableArray<NSValue *> *DPIntegrations;

NSArray<NSValue *> *DPRegisteredTabIntegrations(void) { return DPIntegrations.copy ?: @[]; }
BOOL DPTabIntegrationEnabled(DPTabIntegration *site) { return site && site->patch && site->patch->on && !site->patch->unavailable; }

DPTabIntegration *DPTabIntegrationForURL(id value) {
    DPTabIntegration *match = NULL;
    for (NSValue *entry in DPIntegrations) {
        DPTabIntegration *site = entry.pointerValue;
        if (!DPTabIntegrationEnabled(site) || !DPTabIntegrationMatchesURL(site, value)) continue;
        if (match) return NULL;  // Conflicting providers must not depend on registration order.
        match = site;
    }
    return match;
}

BOOL DPTabIntegrationInstall(DPTabIntegration *site) {
    if (!site || !site->patch) return NO;
    for (NSValue *entry in DPIntegrations) if (entry.pointerValue == site) return YES;
    BOOL valid = site->patch->key.length && site->origins && *site->origins && site->makePreview && DPIntegrationHostAvailable();
    valid &= DPTabIntegrationCanonicalOrigins(site->origins) != nil;
    if (site->scriptKey)
        valid &= site->scriptNamespace.length > 0 && site->scriptVersion > 0 && site->scriptVersion <= UINT32_MAX
            && DPTabIntegrationScript(site->scriptKey) != nil && DPIntegrationBackendAvailable();
    for (NSValue *entry in DPIntegrations) {
        DPTabIntegration *existing = entry.pointerValue;
        if ([existing->patch->key isEqual:site->patch->key]) valid = NO;
    }
    if (!valid) {
        site->patch->unavailable = YES;
        site->patch->on = NO;
        site->patch->progress = 0;
        return NO;
    }
    if (!DPIntegrations) DPIntegrations = [NSMutableArray new];
    [DPIntegrations addObject:[NSValue valueWithPointer:site]];
    DPInstallIntegrationHover();
    if (site->scriptKey) DPInstallIntegrationPages();
    return YES;
}

void DPTabIntegrationApply(DPTabIntegration *site) {
    if (!DPTabIntegrationEnabled(site)) DPTabIntegrationClearCaches(site);
    DPApplyIntegrationHover();
    DPApplyIntegrationPages();
}

NSString *DPTabIntegrationVerify(DPTabIntegration *site) {
    if (!site || site->patch->unavailable) return @"Tab integration is unavailable on this Dia version";
    return DPVerifyIntegrationHover(site);
}
