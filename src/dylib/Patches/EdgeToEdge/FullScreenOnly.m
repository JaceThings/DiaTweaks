#import "EdgeToEdge.h"

DP_PATCH(DPFullScreenOnly) {
    .key = @"fullScreenOnly",
    .defaultOn = NO,
    .order = 15,
    .title = @"Only in Full Screen",
    .detail = @"Remove the padding only when the window is in full screen.",
    .tint = @"systemBlueColor",
    .requires = @"edgeToEdge",
};
