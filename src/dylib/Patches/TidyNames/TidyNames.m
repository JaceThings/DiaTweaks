#import "StdPatch/StdPatch.h"

void DPInstallTidyDownloads(void);

DP_PATCH(DPTidyNames) {
    .key = @"tidyNames", .order = 104, .defaultOn = YES,
    .title = @"Tidy Names",
    .detail = @"Use Apple Intelligence on this Mac to give pinned tabs and downloads clearer names.",
    .symbol = @"sparkles",
    .section = @"Tabs",
    .tint = @"systemPinkColor",
};

DP_PATCH(DPTidyDownloads) {
    .key = @"tidyDownloads", .order = 105, .defaultOn = YES,
    .title = @"Tidy Downloads",
    .detail = @"Use a bundled extension to suggest names for generic downloads. Relaunch Dia after turning this on.",
    .symbol = @"arrow.down.circle",
    .section = @"Tabs",
    .tint = @"systemPinkColor",
    .requires = @"tidyNames",
    .classes = DPClasses("_TtC3ADK36BrowserContextDownloadDelegateBridge", "ArcDownloadItem"),
    .install = DPInstallTidyDownloads,
};

void DPInstallTidyTabTitles(void);

DP_PATCH(DPTidyTabTitles) {
    .key = @"tidyTabTitles", .order = 104, .defaultOn = YES,
    .title = @"Tidy Tab Titles",
    .detail = @"Give tabs shorter titles when you pin them or pin their group.",
    .symbol = @"textformat",
    .section = @"Tabs",
    .tint = @"systemPinkColor",
    .requires = @"tidyNames",
    .classes = DPClasses(DPDiaTabList, DPDiaTabView),
    .install = DPInstallTidyTabTitles,
};
