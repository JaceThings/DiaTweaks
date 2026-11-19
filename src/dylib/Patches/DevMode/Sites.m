#import "DevMode.h"

NSNotificationName const DPDevModeSitesDidChange = @"DPDevModeSitesDidChange";

static NSString *const DPSitesOnKey = @"devModeSitesOn", *const DPLocalOffKey = @"devModeLocalSitesOff";

static NSUserDefaults *DPSiteDefaults(void) {
    static NSUserDefaults *defaults;
    if (!defaults) defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    return defaults;
}

static BOOL DPIsLocal(NSString *host) {
    if ([host isEqualToString:@"localhost"] || [host hasSuffix:@".localhost"]) return YES;
    return [@[ @"127.0.0.1", @"0.0.0.0", @"::1", @"[::1]" ] containsObject:host];
}

static NSArray<NSString *> *DPList(NSString *key) {
    NSArray *list = [DPSiteDefaults() arrayForKey:key];
    return list ?: @[];
}

static void DPSaveList(NSString *key, NSString *host, BOOL present) {
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithArray:DPList(key)];
    if (present) [set addObject:host];
    else [set removeObject:host];
    [DPSiteDefaults() setObject:set.array forKey:key];
}

BOOL DPDevModeOn(NSString *host) {
    if (!host.length) return NO;
    if (DPIsLocal(host)) return ![DPList(DPLocalOffKey) containsObject:host];
    return [DPList(DPSitesOnKey) containsObject:host];
}

void DPSetDevModeOn(NSString *host, BOOL on) {
    if (!host.length || DPDevModeOn(host) == on) return;
    if (DPIsLocal(host)) DPSaveList(DPLocalOffKey, host, !on);
    else DPSaveList(DPSitesOnKey, host, on);
    [NSNotificationCenter.defaultCenter postNotificationName:DPDevModeSitesDidChange object:host];
}
