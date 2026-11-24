#import "Easels.h"
#import "Assets.h"
#import "HostInternal.h"
void DPEaselInstallPortableOpen(void);
static void DPApplyEasels(DPPatch *patch) {
    [DPEaselHost refresh];
    DPEaselRefreshMetadata();
    DPEaselRefreshAddressFields();
    if(!patch->on) [DPEaselImageCache.shared clear];
    [NSNotificationCenter.defaultCenter postNotificationName:@"DPLibrarySectionsChanged" object:nil];
}
static void DPInstallEasels(void) {
    [DPEaselHost install]; DPEaselInstallPortableOpen();
    DPEaselInstallNativeAddress();
    DPEaselRegisterLibrary(); DPEaselRegisterAddressTitle();
    DPOnLaunch(^{ DPEaselInstallCreateMenu(); DPEaselInstallTabMenus(); });
    DPOnQuit(^{ [DPEaselHost finishEditing]; [DPEaselStore.shared flush]; });
}
static NSString *DPVerifyEasels(DPPatch *patch) {
    if(patch->on) return nil; // The off check observes owned views, independent of hook execution.
    return DPFindViews("DPEaselEditorSurface").count ? @"Easel editor remains mounted while disabled" : nil;
}
DP_PATCH(DPEasels) {
    .key=@"easels", .defaultOn=YES, .order=89, .title=@"Easels",
    .detail=@"Keep local visual boards with images, text and drawings in your Library.",
    .symbol=@"pencil.and.outline", .tint=@"systemTealColor", .section=@"Sidebar & Tab Bar",
    .requires=@"sidebarLibrary", .classes=DPClasses(DPDiaWebContents,DPDiaNavigationController),
    .install=DPInstallEasels, .apply=DPApplyEasels, .verify=DPVerifyEasels,
};
