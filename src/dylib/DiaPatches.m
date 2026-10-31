// The add-on's entry point: Dia loads this dylib before its own code runs. Patches register themselves with DP_PATCH.
#import "StdPatch/StdPatch.h"
#import "SafeMode/SafeMode.h"
#import "Settings/Settings.h"
#import "Updates/Updates.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import "Test/Test.h"
#import "DevTools/DevTools.h"

__attribute__((constructor)) static void DPInit(void) {
    DPBeginLaunch();
    if (DPSafeMode == 2) return;
    DPLoadPatches();
    if (!DPSafeMode) {
        DPInstallPatches();
        DPInstallGroupTabs();
    }
    DPInstallSettings();
    DPInstallUpdates();
    DPInstallDevTools();

    NSString *report = NSProcessInfo.processInfo.environment[@"DIAPATCH_TEST"];
    unsetenv("DIAPATCH_TEST");  // Dia relaunched from Settings would inherit it and test again.
    if (report) DPRunTests(report);
}
