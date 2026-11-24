#import "Tasks.h"
#import "Patches/SidebarLibrary/Sections.h"
static void DPInstallTasks(void) {
    DPTasksRegisterLibrary();
    DPOnQuit(^{ [DPTaskStore flushAll]; });
}
static void DPApplyTasks(DPPatch *patch) { [NSNotificationCenter.defaultCenter postNotificationName:DPLibrarySectionsChanged object:nil]; }
static NSString *DPVerifyTasks(DPPatch *patch) {
    if(!patch->on && DPFindViews("DPTaskContent").count) return @"Tasks remains mounted while disabled";
    return nil;
}
DP_PATCH(DPTasks) {
    .key=@"tasks", .defaultOn=YES, .order=90, .title=@"Tasks",
    .detail=@"Keep a simple local task list in Library. Completed and cleared tasks remain recoverable.",
    .symbol=@"checklist", .tint=@"systemTealColor", .section=@"Sidebar & Tab Bar",
    .requires=@"sidebarLibrary", .install=DPInstallTasks, .apply=DPApplyTasks, .verify=DPVerifyTasks,
};
