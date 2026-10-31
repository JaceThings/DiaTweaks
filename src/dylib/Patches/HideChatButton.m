#import "../DiaPatches.h"

static NSColor *DPPurple(void) { return NSColor.systemPurpleColor; }

DPPatch DPHideChatButton = {
    .key = @"hideChatButton",
    .title = @"Hide Chat button",
    .detail = @"Hide the Chat button at the top right of the toolbar.",
    .symbol = @"bubble.fill",
    .tint = DPPurple,
    .disabledBy = &DPHideToolbar,
    .apply = DPApplyButtons,
};
