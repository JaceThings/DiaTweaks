#import <dlfcn.h>
#import "StdPatch/StdPatch.h"
#import "SafeMode/SafeMode.h"

// Stand-ins for what the patches ask of the rest of the dylib.
void DPApplyHides(DPPatch *patch) {}
NSString *DPVerifyHides(DPPatch *patch) { return nil; }
void DPInstallHides(void) {}
void DPOnLaunch(void (^block)(void)) {}
void DPOnQuit(void (^block)(void)) {}

// The launch guard keeps its state beside the dylib: point it at a temporary folder.
static const char *DPTestDylib;
static int DPTestDladdr(const void *address, Dl_info *info) {
    int found = dladdr(address, info);
    info->dli_fname = DPTestDylib;
    return found;
}
#define dladdr DPTestDladdr

static int applied;
static BOOL lastOn;
static void DPApplyStub(DPPatch *patch) {
    applied++;
    lastOn = patch->on;
}

DP_PATCH(DPStub) {
    .key = @"pauseTest",
    .title = @"Pause Test",
    .detail = @"",
    .apply = DPApplyStub,
};

#import "SafeMode/SafeMode.m"
#import "StdPatch/Patch.m"

static int failures;

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL %s\n", what.UTF8String);
}

int main(void) {
    @autoreleasepool {
        NSString *temporary = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
        NSString *support = [temporary stringByAppendingPathComponent:@"support"];
        [NSFileManager.defaultManager createDirectoryAtPath:support withIntermediateDirectories:YES attributes:nil error:nil];
        DPTestDylib = [[support stringByAppendingPathComponent:@"DiaPatches.dylib"] fileSystemRepresentation];
        NSString *pause = [support stringByAppendingPathComponent:@"paused"];

        // A registered default stands in for a saved setting, so the test writes nobody's settings.
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches.pause-test"];
        [defaults registerDefaults:@{ @"pauseTest" : @YES }];
        DPDefaults = defaults;
        static DPPatch *patches[] = { &DPStub };
        DPPatches = patches;
        DPPatchCount = 1;

        DPBeginLaunch();
        expect(!DPPaused, @"a launch without the pause file isn't paused");
        DPStub.on = DPEffectiveOn(&DPStub);  // what DPLoadPatches does
        expect(DPSavedOn(&DPStub) && DPStub.on, @"it starts on, as saved");

        // Pausing turns it off at once, and leaves what's saved alone.
        [NSData.data writeToFile:pause atomically:YES];
        DPApplySavedSettings();
        expect(DPPaused && !DPStub.on && applied == 1 && !lastOn, @"pausing turns it off");
        expect(DPSavedOn(&DPStub), @"pausing keeps its saved setting");

        // Nothing turns on while paused.
        DPSetPatch(&DPStub, YES, NO);
        expect(!DPStub.on && applied == 1, @"a tweak can't be turned on while paused");

        // Resuming gives back exactly what was saved.
        [NSFileManager.defaultManager removeItemAtPath:pause error:nil];
        DPApplySavedSettings();
        expect(!DPPaused && DPStub.on && applied == 2 && lastOn, @"resuming turns it back on");

        // A launch while paused starts with everything off, and the saved setting is still there.
        [NSData.data writeToFile:pause atomically:YES];
        DPBeginLaunch();
        DPStub.on = DPEffectiveOn(&DPStub);
        expect(DPPaused && !DPStub.on && DPSavedOn(&DPStub), @"a launch while paused starts with it off");

        // Leaving safe mode is not resuming.
        DPLeaveSafeMode();
        expect(DPPauseSaved(), @"leaving safe mode leaves the pause alone");

        [NSFileManager.defaultManager removeItemAtPath:temporary error:nil];
    }
    if (!failures) printf("all pause checks passed\n");
    return failures ? 1 : 0;
}
