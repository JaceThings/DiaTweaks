#import "StdPatch/StdPatch.h"
#import "StdPatch/Hide.h"

static BOOL DPIsUpgradeBanner(NSView *view) { return DPIsKind(view, DPDiaChatUsage); }

// The banner is in the command bar, which isn't one of the places StdPatch looks, so its own layout hides it.
static void DPChatUsage_layout(NSView *self, SEL _cmd) {
    [DPHideHosts addObject:self];
    DPEnforceHides(self);
    DPCallOriginal(DPChatUsage_layout, self);
}

static void DPInstallHideUpgradeBanner(void) {
    DPHook(DPDiaChatUsage, @selector(layout), (IMP)DPChatUsage_layout);
}

DP_PATCH(DPHideUpgradeBanner) {
    .key = @"hideUpgradeBanner",
    .order = 96,
    .section = @"Command Bar",
    .title = @"Hide upgrade banner",
    .detail = @"Hide the “Looking for chat?” upgrade banner under the command bar.",
    .symbol = @"sparkles",
    .tint = @"systemYellowColor",
    .classes = DPClasses(DPDiaChatUsage),
    .hides = DPIsUpgradeBanner,
    .install = DPInstallHideUpgradeBanner,
};
