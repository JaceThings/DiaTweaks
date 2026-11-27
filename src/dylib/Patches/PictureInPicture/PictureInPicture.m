#import "PictureInPicture.h"

static void DPInstallPiP(void) { DPOnLaunch(^{ DPInstallPiPLayout(); DPApplyPiP(NULL); }); }

#define DPPIP_CLASSES DPClasses(DPPiPContentClass, DPPiPOverlayClass)

DP_PATCH(DPPiPIconOnly) {
    .key = @"pipIconOnlyButtons", .order = 110,
    .title = @"Icon-Only PiP Buttons",
    .detail = @"Show only icons for Back to Tab and Close at every Picture in Picture size.",
    .symbol = @"pip", .tint = @"systemRedColor", .section = @"Picture in Picture",
    .classes = DPPIP_CLASSES, .install = DPInstallPiP, .apply = DPApplyPiP, .verify = DPVerifyPiP,
};

DP_PATCH(DPPiPSmallPlayPause) {
    .key = @"pipSmallPlayPause", .order = 111,
    .title = @"Smaller PiP Playback Controls",
    .detail = @"Show backward, play/pause and forward at 50% of their normal size as the PiP window is resized.",
    .symbol = @"playpause.fill", .tint = @"systemRedColor", .section = @"Picture in Picture",
    .classes = DPPIP_CLASSES, .apply = DPApplyPiP, .verify = DPVerifyPiP,
};

DP_PATCH(DPPiPHideDomain) {
    .key = @"pipHideDomain", .order = 112,
    .title = @"Hide PiP Domain",
    .detail = @"Hide the website name above the video in Picture in Picture.",
    .symbol = @"globe", .tint = @"systemRedColor", .section = @"Picture in Picture",
    .classes = DPPIP_CLASSES, .apply = DPApplyPiP, .verify = DPVerifyPiP,
};
