#import "Library.h"
void DPLibraryStopDissolves(void);
static void DPApplyLibraryDust(DPPatch *patch) { if(!patch->on) DPLibraryStopDissolves(); }
DP_PATCH(DPSidebarLibraryDust) {
    .key = @"sidebarLibraryDust", .defaultOn = YES, .order = 87,
    .title = @"Thanos removal effect",
    .detail = @"Dissolve items into fine dust when hiding them or clearing Library Archive. Turn off for immediate removal.",
    .symbol = @"sparkles", .tint = @"systemTealColor", .section = @"Sidebar & Tab Bar",
    .requires = @"sidebarLibrary", .apply = DPApplyLibraryDust,
};
