#import "TabIntegrations/ConversationPreview.h"

extern DPPatch DPGeminiPreview;
static BOOL matchesURL(NSString *value) {
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    if (parts.user.length || parts.password.length || parts.query != nil || parts.fragment != nil) return NO;
    NSString *path = parts.path;
    if (!path) return NO;
    return [path isEqual:@"/"] || [path isEqual:@"/app"]
        || [path rangeOfString:@"^/(?:u/[0-9]+/)?app(?:/[A-Za-z0-9_-]{1,128})?$" options:NSRegularExpressionSearch].location != NSNotFound;
}
static DPTabIntegrationPreview *makePreview(DPTabIntegration *site, id tab) {
    DPTabIntegrationConversationPreview *preview = [[DPTabIntegrationConversationPreview alloc] initWithIntegration:site tab:tab];
    preview.providerTitle = @"Gemini";
    return preview;
}
static DPTabIntegration site = {
    .patch = &DPGeminiPreview,
    .origins = DPIntegrationOrigins("https://gemini.google.com"),
    .matchesURL = matchesURL,
    .scriptKey = @"GeminiPreview", .scriptNamespace = @"DiaGeminiPreview", .scriptVersion = 1,
    .snapshotChanged = DPConversationSnapshotChanged, .makePreview = makePreview,
};
static void install(void) { DPTabIntegrationInstall(&site); }
static void apply(DPPatch *patch) { DPTabIntegrationApply(&site); }
static NSString *verify(DPPatch *patch) { return DPTabIntegrationVerify(&site); }
DP_PATCH(DPGeminiPreview) {
    .key = @"geminiPreview", .order = 77,
    .title = @"Gemini",
    .detail = @"Show recent Gemini conversations when hovering a tab, with a separate preview pin and conversation shortcuts. Experimental; live activity and unread status are not yet supported.",
    .symbol = @"sparkles", .tint = @"systemBlueColor", .section = @"Websites",
    .requires = @"extendedIntegrations",
    .classes = DPTabIntegrationClasses, .install = install, .apply = apply, .verify = verify,
};
