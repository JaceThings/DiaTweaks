#import "Updates/Updates.h"

static NSString *DPLaunchedRelease;

static NSString *DPHome(NSString *name) {
    return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"DiaPatches"] stringByAppendingPathComponent:name];
}

static NSString *DPCLI(void) { return DPHome(@"bin/diapatch"); }

static NSUserDefaults *DPSettingsDefaults(void) { return [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; }

BOOL DPAutoUpdates(void) { return [DPSettingsDefaults() objectForKey:@"autoUpdate"] ? [DPSettingsDefaults() boolForKey:@"autoUpdate"] : YES; }

void DPSetAutoUpdates(BOOL on) { [DPSettingsDefaults() setBool:on forKey:@"autoUpdate"]; }

void DPRunCLI(NSArray<NSString *> *args, void (^completion)(NSString *output)) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSTask *task = [NSTask new];
        task.executableURL = [NSURL fileURLWithPath:DPCLI()];
        task.arguments = args;
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = NSFileHandle.fileHandleWithNullDevice;
        NSString *output = nil;
        if ([task launchAndReturnError:nil]) {
            NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
            [task waitUntilExit];
            if (task.terminationStatus == 0) output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(output); });
    });
}

void DPHandOffAndQuit(NSString *command) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:DPCLI()];
    task.arguments = @[command, @"--wait", @(getpid()).stringValue, @"--relaunch"];
    if ([task launchAndReturnError:nil]) [NSApp terminate:nil];
}

static NSString *DPStagedPath(void) {
    return [DPCLI().stringByDeletingLastPathComponent.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"staged/Dia.app"];
}

static void DPUpdateDiaAndTweaks(void (^done)(void)) {
    DPRunCLI(@[@"update"], ^(NSString *_) {
        DPRunCLI(@[@"self-update"], ^(NSString *_) { if (done) done(); });
    });
}

void DPCheckForUpdates(void (^completion)(NSDictionary *status)) {
    DPUpdateDiaAndTweaks(^{
        DPRunCLI(@[@"status", @"--json"], ^(NSString *output) {
            id status = output ? [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
            completion([status isKindOfClass:NSDictionary.class] ? status : nil);
        });
    });
}

NSString *DPPendingUpdate(NSDictionary *status) {
    id dia = status[@"staged"], tweaks = status[@"release"];
    BOOL newTweaks = [tweaks isKindOfClass:NSString.class] && ![tweaks isEqual:DPLaunchedRelease];
    if ([dia isKindOfClass:NSString.class])
        return newTweaks ? [NSString stringWithFormat:@"Dia %@ and DiaTweaks %@", dia, tweaks] : [@"Dia " stringByAppendingString:dia];
    return newTweaks ? [@"DiaTweaks " stringByAppendingString:tweaks] : nil;
}

static void DPShowUpdateAlert(void) {
    DPCheckForUpdates(^(NSDictionary *status) {
        NSAlert *alert = [NSAlert new];
        NSString *pending = DPPendingUpdate(status);
        if (pending) {
            alert.messageText = [pending stringByAppendingString:@" is ready"];
            alert.informativeText = @"It’s installed when you quit Dia.";
            [alert addButtonWithTitle:@"Relaunch Now"];
            [alert addButtonWithTitle:@"Later"];
            if ([alert runModal] == NSAlertFirstButtonReturn) DPHandOffAndQuit(@"apply");
        } else {
            alert.messageText = status ? @"Dia is up to date" : @"Couldn’t check for updates";
            [alert runModal];
        }
    });
}

static void DPApplyStagedOnQuit(void) {
    if (![NSFileManager.defaultManager fileExistsAtPath:DPStagedPath()]) return;
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:DPCLI()];
    task.arguments = @[@"apply", @"--wait", @(getpid()).stringValue];
    [task launchAndReturnError:nil];
}

void DPInstallUpdates(void) {
    DPLaunchedRelease = [NSDictionary dictionaryWithContentsOfFile:DPHome(@"release.plist")][@"tag"];
    DPOnLaunch(^{
        DPOnMenuItem(nil, @"Check for Updates", ^{ DPShowUpdateAlert(); });
        if (DPAutoUpdates()) DPUpdateDiaAndTweaks(nil);
    });
    DPOnQuit(^{ DPApplyStagedOnQuit(); });
}
