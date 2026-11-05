#import "TabIntegrations/ConversationPreview.h"

extern DPPatch DPClaudePreview;

static BOOL DPClaudePreviewMatchesURL(NSString *value) {
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    if (!parts || parts.user.length || parts.password.length || parts.query != nil || parts.fragment != nil
        || ![parts.scheme.lowercaseString isEqual:@"https"] || ![parts.host.lowercaseString isEqual:@"claude.ai"]
        || (parts.port && parts.port.integerValue != 443)) return NO;
    NSString *path = parts.path ?: @"";
    if ([path isEqual:@"/"] || [path isEqual:@"/new"]) return YES;
    return [path rangeOfString:@"^/chat/[A-Za-z0-9_-]{1,128}$" options:NSRegularExpressionSearch].location != NSNotFound;
}

static DPTabIntegrationPreview *DPClaudeMakePreview(DPTabIntegration *integration, id tab) {
    DPTabIntegrationConversationPreview *preview = [[DPTabIntegrationConversationPreview alloc] initWithIntegration:integration tab:tab];
    preview.providerTitle = @"Claude";
    return preview;
}

DPTabIntegration DPClaudeIntegration = {
    .patch = &DPClaudePreview,
    .origins = DPIntegrationOrigins("https://claude.ai"),
    .matchesURL = DPClaudePreviewMatchesURL,
    .scriptKey = @"ClaudePreview",
    .scriptNamespace = @"DiaClaudePreview",
    .scriptVersion = 1,
    .snapshotChanged = DPConversationSnapshotChanged,
    .makePreview = DPClaudeMakePreview,
};

static void DPInstallClaudePreview(void) { DPTabIntegrationInstall(&DPClaudeIntegration); }
static void DPApplyClaudePreview(DPPatch *patch) { DPTabIntegrationApply(&DPClaudeIntegration); }
static NSString *DPVerifyClaudePreview(DPPatch *patch) { return DPTabIntegrationVerify(&DPClaudeIntegration); }

DP_PATCH(DPClaudePreview) {
    .key = @"claudePreview",
    .order = 76,
    .title = @"Claude",
    .detail = @"Show recent Claude conversations when hovering a tab. Pin one conversation in the preview. Experimental.",
    .symbol = @"bubble.left.and.bubble.right",
    .tint = @"systemGreenColor",
    .section = @"Websites",
    .requires = @"extendedIntegrations",
    .classes = DPTabIntegrationClasses,
    .install = DPInstallClaudePreview,
    .apply = DPApplyClaudePreview,
    .verify = DPVerifyClaudePreview,
};
