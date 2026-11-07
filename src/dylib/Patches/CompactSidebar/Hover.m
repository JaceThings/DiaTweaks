#import "CompactSidebar.h"

// Off, the strip stays a strip under the pointer; the whole sidebar is still a ⌘S away.
static void DPApplyCompactSidebarHover(DPPatch *patch) { DPRelayoutCompactSidebar(); }

DP_PATCH(DPCompactSidebarHover) {
    .key = @"compactSidebarOpenOnHover",
    .order = 78,
    .title = @"Open Sidebar on Hover",
    .detail = @"Open the whole sidebar over the page while the pointer is on the strip.",
    .symbol = @"cursorarrow.rays",
    .tint = @"systemTealColor",
    .requires = @"compactSidebar",
    .defaultOn = YES,
    .apply = DPApplyCompactSidebarHover,
};
