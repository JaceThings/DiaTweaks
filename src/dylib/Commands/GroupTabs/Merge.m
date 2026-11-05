#import "GroupTabs.h"

// Nothing to redraw: Group Tabs reads the switch the next time it runs.
static void DPApplyMergeSubdomains(DPPatch *patch) {}

DP_PATCH(DPGroupTabsMergeSubdomains) {
    .key = @"groupTabsMergeSubdomains",
    .order = 86,
    .title = @"Merge Subdomains",
    .detail = @"Group tabs from the same site together, so gist.github.com joins github.com.",
    .symbol = @"arrow.triangle.merge",
    .tint = @"systemPinkColor",
    .requires = @"groupTabsByDomain",
    .apply = DPApplyMergeSubdomains,
};
