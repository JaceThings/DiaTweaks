#import "CompactCommandBar.h"

DP_PATCH(DPCompactWithChat) {
    .key = @"compactCommandBarWithChat",
    .order = 98,
    .title = @"Compact with chat usage too",
    .detail = @"Fit the command bar on one line even with chat usage. This hides Add tabs or files and dictation, so you can't use them from the command bar while it's on.",
    .symbol = @"exclamationmark.triangle",
    .tint = @"systemOrangeColor",
    .requires = @"compactCommandBar",
    .apply = DPApplyCompactCommandBar,
};
