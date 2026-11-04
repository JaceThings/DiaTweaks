#import "ChatGPTPreview.h"
#import "Cache.h"

static DPTabIntegrationPreview *DPChatGPTMakePreview(DPTabIntegration *integration, id tab) {
    return [[DPChatGPTCard alloc] initWithIntegration:integration tab:tab];
}

DPTabIntegration DPChatGPTIntegration = {
    .patch = &DPChatGPTPreview,
    .origins = DPIntegrationOrigins("https://chatgpt.com"),
    .scriptKey = @"ChatGPTPreview",
    .scriptNamespace = @"DiaChatGPTPreview",
    .scriptVersion = 3,
    .snapshotChanged = DPChatGPTSnapshotChanged,
    .makePreview = DPChatGPTMakePreview,
};

static void DPInstallChatGPTPreview(void) { DPTabIntegrationInstall(&DPChatGPTIntegration); }
static void DPApplyChatGPTPreview(DPPatch *patch) {
    DPTabIntegrationApply(&DPChatGPTIntegration);
}
static NSString *DPVerifyChatGPTPreview(DPPatch *patch) { return DPTabIntegrationVerify(&DPChatGPTIntegration); }

DP_PATCH(DPChatGPTPreview) {
    .key = @"chatgptPreview",
    .order = 75,
    .title = @"ChatGPT Tab Preview",
    .detail = @"Show recent ChatGPT conversations when hovering a tab. Pin one conversation in the preview, switch to a conversation, and follow ChatGPT’s own working and unread indicators. Experimental.",
    .symbol = @"bubble.left.and.bubble.right",
    .tint = @"systemGreenColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPTabIntegrationClasses,
    .install = DPInstallChatGPTPreview,
    .apply = DPApplyChatGPTPreview,
    .verify = DPVerifyChatGPTPreview,
};
