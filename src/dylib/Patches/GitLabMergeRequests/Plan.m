#import "Plan.h"

const NSTimeInterval DPGitLabDepartureGrace = 600;

// A member seen before any fetch said when its MR last changed: if the user closes it, it stays away until the next change
// after the first one a fetch reports.
static NSString *const DPGitLabUnknownUpdate = @"?";

NSString *DPGitLabURLHost(NSString *url) {
    NSURLComponents *parts = url ? [NSURLComponents componentsWithString:url] : nil;
    NSString *host = parts.host.lowercaseString;
    return host.length && parts.port ? [host stringByAppendingFormat:@":%@", parts.port] : host.length ? host : nil;
}

NSString *DPGitLabMRKey(NSString *url, NSArray<NSString *> *hosts) {
    NSURLComponents *parts = url ? [NSURLComponents componentsWithString:url] : nil;
    NSString *host = DPGitLabURLHost(url);
    if (!host || !([parts.scheme isEqual:@"https"] || [parts.scheme isEqual:@"http"])) return nil;
    if (![hosts containsObject:host]) return nil;
    NSRange marker = [parts.path rangeOfString:@"/-/merge_requests/"];
    if (marker.location == NSNotFound || marker.location == 0) return nil;
    NSString *project = [parts.path substringWithRange:NSMakeRange(1, marker.location - 1)];
    NSString *rest = [parts.path substringFromIndex:NSMaxRange(marker)];
    NSString *iid = [rest componentsSeparatedByString:@"/"].firstObject;
    NSCharacterSet *notDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    if (!iid.length || [iid rangeOfCharacterFromSet:notDigits].location != NSNotFound) return nil;
    return [NSString stringWithFormat:@"%@/%@!%@", host, project, iid];
}

@implementation DPGitLabMR
+ (instancetype)key:(NSString *)key url:(NSString *)url updatedAt:(NSString *)updatedAt {
    DPGitLabMR *mr = [self new];
    mr.key = key, mr.url = url, mr.updatedAt = updatedAt;
    return mr;
}
@end

@implementation DPGitLabTab
+ (instancetype)key:(NSString *)key tab:(NSString *)tabID inFolder:(BOOL)inFolder selected:(BOOL)selected {
    DPGitLabTab *tab = [self new];
    tab.key = key, tab.tabID = tabID, tab.inFolder = inFolder, tab.selected = selected;
    return tab;
}
@end

@implementation DPGitLabPlanState
- (instancetype)init {
    if ((self = [super init])) _departures = @{}, _hidden = @{}, _members = @{};
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    DPGitLabPlanState *copy = [DPGitLabPlanState new];
    copy.departures = self.departures, copy.hidden = self.hidden, copy.members = self.members;
    return copy;
}
@end

@implementation DPGitLabPlan
@end

DPGitLabPlan *DPGitLabMakePlan(NSArray<DPGitLabTab *> *tabs, NSArray<DPGitLabMR *> *fetched, BOOL enabled,
                               DPGitLabPlanState *state, NSDate *now) {
    DPGitLabPlan *plan = [DPGitLabPlan new];
    plan.inserts = @[], plan.moves = @[], plan.closes = @[];
    state = state ?: [DPGitLabPlanState new];
    NSMutableDictionary *hidden = [state.hidden mutableCopy], *departures = [NSMutableDictionary new];
    NSMutableDictionary<NSString *, NSMutableArray<DPGitLabTab *> *> *inFolder = [NSMutableDictionary new], *loose = [NSMutableDictionary new];
    for (DPGitLabTab *tab in tabs) {
        NSMutableDictionary *side = tab.inFolder ? inFolder : loose;
        if (!side[tab.key]) side[tab.key] = [NSMutableArray new];
        [side[tab.key] addObject:tab];
    }
    // A member the last plan left in the folder that has gone without this plan closing it: the user closed it or
    // dragged it out. Remember it so it stays away until it changes.
    for (NSString *key in state.members)
        if (!inFolder[key]) hidden[key] = state.members[key];

    NSMutableArray *inserts = [NSMutableArray new], *moves = [NSMutableArray new], *closes = [NSMutableArray new];
    NSMutableDictionary *members = [NSMutableDictionary new];
    void (^close)(DPGitLabTab *) = ^(DPGitLabTab *tab) { [closes addObject:tab.tabID]; };

    if (!enabled) {
        for (NSString *key in inFolder)
            for (DPGitLabTab *tab in inFolder[key]) {
                if (tab.selected) members[key] = state.members[key] ?: DPGitLabUnknownUpdate;
                else close(tab);
            }
    } else if (!fetched) {
        // A failed fetch says nothing about the MRs: keep the folder as it is and the clocks running.
        [departures addEntriesFromDictionary:state.departures];
        for (NSString *key in inFolder) members[key] = state.members[key] ?: DPGitLabUnknownUpdate;
    } else {
        NSMutableDictionary<NSString *, DPGitLabMR *> *open = [NSMutableDictionary new];
        for (DPGitLabMR *mr in fetched) open[mr.key] = mr;
        for (DPGitLabMR *mr in fetched) {
            if ([hidden[mr.key] isEqual:DPGitLabUnknownUpdate]) hidden[mr.key] = mr.updatedAt;
            if (hidden[mr.key] && [hidden[mr.key] isEqual:mr.updatedAt]) continue;
            [hidden removeObjectForKey:mr.key];
            if (inFolder[mr.key]) continue;
            // Not a member until a refresh sees it in the folder, so one that didn't land isn't taken for one the user closed.
            if (loose[mr.key]) [moves addObject:loose[mr.key].firstObject.tabID];
            else [inserts addObject:mr];
        }
        for (NSString *key in inFolder) {
            NSArray<DPGitLabTab *> *copies = inFolder[key];
            DPGitLabTab *keep = copies.firstObject;
            for (DPGitLabTab *tab in copies) if (tab.selected) keep = tab;
            for (DPGitLabTab *tab in copies) if (tab != keep && !tab.selected) close(tab);  // Duplicates.
            if (open[key]) {
                members[key] = open[key].updatedAt;
                continue;
            }
            NSDate *left = state.departures[key] ?: now;
            if ([now timeIntervalSinceDate:left] >= DPGitLabDepartureGrace && !keep.selected) {
                close(keep);
                continue;
            }
            departures[key] = left;
            members[key] = state.members[key] ?: DPGitLabUnknownUpdate;
        }
        // An MR no longer open can't come back from the user's closing it as it was.
        for (NSString *key in hidden.allKeys) if (!open[key]) [hidden removeObjectForKey:key];
    }
    plan.inserts = inserts, plan.moves = moves, plan.closes = closes;
    plan.state = [DPGitLabPlanState new];
    plan.state.departures = departures, plan.state.hidden = hidden, plan.state.members = members;
    return plan;
}
