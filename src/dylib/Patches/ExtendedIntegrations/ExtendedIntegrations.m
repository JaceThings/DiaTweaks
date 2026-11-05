#import "TabIntegrations/TabIntegrations.h"

static void apply(DPPatch *patch) { DPTabIntegrationApplyAll(); }

DP_PATCH(DPExtendedIntegrations) {
    .key = @"extendedIntegrations",
    // Existing per-site preferences stay effective when upgrading; individual sites remain opt-in.
    .defaultOn = YES,
    .order = 74,
    .title = @"Extended Integrations",
    .detail = @"Enhance website tab previews. Choose which integrations to enable below. Turning this off pauses them without changing your website selections.",
    .symbol = @"puzzlepiece.extension",
    .tint = @"systemBlueColor",
    .section = @"Tabs",
    .classes = DPTabIntegrationClasses,
    .apply = apply,
};
