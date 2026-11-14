#import "StdPatch/StdPatch.h"
#import "Patches/AgentTransport/AgentRelay.h"

NSData *DPChatAgentRequest(NSData *line, NSString *model);
NSArray<NSString *> *DPInstalledChatModels(void);
NSString *DPSelectedDiaChatModel(NSString *choice, NSArray<NSString *> *models, BOOL fallback);

extern DPPatch DPDiaChatModel, DPDiaChatModelFallback;
void DPInstallDiaModelOverview(void);
void DPRefreshDiaModelPicker(void);
NSString *DPVerifyDiaModelOverview(DPPatch *patch);

static NSString *const DPDefaultDiaModel = @"dia-default";

void DPApplyDiaChatModel(DPPatch *patch) {
    NSString *choice = patch->on ? DPChoice(patch) : nil;
    NSString *model = DPSelectedDiaChatModel(choice, DPInstalledChatModels(), DPDiaChatModelFallback.on);
    DPAgentFilter filter = nil;
    if (patch->on) filter = ^NSData *(NSData *line, DPAgentReply reply) {
        return DPChatAgentRequest(line, model);
    };
    DPSetAgentFilters(patch->key, filter, nil);
    DPRefreshDiaModelPicker();
    [NSNotificationCenter.defaultCenter postNotificationName:DPPatchesDidChangeNotification object:nil];
}

static void DPInstallDiaChatModel(void) {
    DPInstallDiaModelOverview();
    DPApplyDiaChatModel(&DPDiaChatModel);
    DPOnLaunch(^{ DPApplyDiaChatModel(&DPDiaChatModel); });
}

NSMenu *DPDiaChatModels(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Model"];
    [menu addItemWithTitle:@"Dia Default" action:nil keyEquivalent:@""].representedObject = DPDefaultDiaModel;
    NSArray *models = DPInstalledChatModels();
    for (NSString *model in models)
        [menu addItemWithTitle:model action:nil keyEquivalent:@""].representedObject = model;
    NSString *saved = DPChoice(&DPDiaChatModel);
    if (!DPDiaChatModelFallback.on && saved.length && ![saved isEqual:DPDefaultDiaModel] && ![models containsObject:saved])
        [menu addItemWithTitle:saved action:nil keyEquivalent:@""].representedObject = saved;
    return menu;
}

DP_PATCH(DPDiaChatModel) {
    .key = @"diaChatModel",
    .order = 103,
    .title = @"Chat Model",
    .detail = @"Restart Dia if this tweak was off when Dia opened.",
    .hint = @"Model availability depends on your account.",
    .symbol = @"sparkles",
    .tint = @"systemPurpleColor",
    .section = @"AI",
    .classes = DPClasses(DPDiaCommandBarToolbar),
    .choice = @"diaChatModelChoice",
    .defaultChoice = @"dia-default",
    .choices = DPDiaChatModels,
    .install = DPInstallDiaChatModel,
    .apply = DPApplyDiaChatModel,
    .verify = DPVerifyDiaModelOverview,
};
