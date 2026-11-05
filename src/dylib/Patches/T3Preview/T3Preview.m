#import "TabIntegrations/TabIntegrations.h"
#import "TabIntegrations/ConversationPreview.h"

extern DPPatch DPT3Preview;

static BOOL DPT3MatchesURL(NSString *value) {
    if (!DPTabIntegrationAllowsURL(value, DPIntegrationOrigins("https://t3.chat"))) return NO;
    NSURLComponents *components = [NSURLComponents componentsWithString:value];
    if (!components || components.user || components.password || components.query || components.fragment) return NO;
    NSString *path = components.path ?: @"";
    if ([path isEqual:@"/"]) return YES;
    NSRegularExpression *route = [NSRegularExpression regularExpressionWithPattern:@"^/chat/[A-Za-z0-9_-]{1,128}$" options:0 error:nil];
    return [route firstMatchInString:path options:0 range:NSMakeRange(0, path.length)] != nil;
}

static DPTabIntegrationPreview *DPT3MakePreview(DPTabIntegration *integration, id tab) {
    DPTabIntegrationConversationPreview *preview = [[DPTabIntegrationConversationPreview alloc] initWithIntegration:integration tab:tab];
    preview.providerTitle = @"T3 Chat";
    return preview;
}

DPTabIntegration DPT3Integration = {
    .patch = &DPT3Preview,
    .origins = DPIntegrationOrigins("https://t3.chat"),
    .matchesURL = &DPT3MatchesURL,
    .scriptKey = @"T3Preview",
    .scriptNamespace = @"DiaT3Preview",
    .scriptVersion = 1,
    .snapshotChanged = DPConversationSnapshotChanged,
    .makePreview = DPT3MakePreview,
};

static void DPT3Install(void) { DPTabIntegrationInstall(&DPT3Integration); }
static void DPT3Apply(DPPatch *patch) { DPTabIntegrationApply(&DPT3Integration); }
static NSString *DPT3Verify(DPPatch *patch) { return DPTabIntegrationVerify(&DPT3Integration); }

DP_PATCH(DPT3Preview) {
    .key = @"t3Preview",
    .order = 78,
    .title = @"T3 Chat",
    .detail = @"Show recent t3.chat conversations when hovering a tab. Pin one conversation in the preview. Experimental.",
    .symbol = @"bubble.left.and.bubble.right",
    .tint = @"systemGreenColor",
    .section = @"Websites",
    .requires = @"extendedIntegrations",
    .classes = DPTabIntegrationClasses,
    .install = DPT3Install,
    .apply = DPT3Apply,
    .verify = DPT3Verify,
};
