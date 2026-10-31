#import "Updates/Updates.h"

static NSString *DPCLI(void) {
    return [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"DiaPatches/bin/diapatch"];
}

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

void DPCheckForUpdates(void (^completion)(NSDictionary *status)) {
    DPRunCLI(@[@"update"], ^(NSString *_) {
        DPRunCLI(@[@"status", @"--json"], ^(NSString *output) {
            id status = output ? [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
            completion([status isKindOfClass:NSDictionary.class] ? status : nil);
        });
    });
}

static void DPShowUpdateAlert(void) {
    DPCheckForUpdates(^(NSDictionary *status) {
        NSAlert *alert = [NSAlert new];
        id staged = status[@"staged"];
        if ([staged isKindOfClass:NSString.class]) {
            alert.messageText = [NSString stringWithFormat:@"Dia %@ is ready", staged];
            alert.informativeText = @"It will be installed with your patches when you quit Dia.";
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
    DPOnLaunch(^{
        DPOnMenuItem(nil, @"Check for Updates", ^{ DPShowUpdateAlert(); });
        DPRunCLI(@[@"update"], nil);
    });
    DPOnQuit(^{ DPApplyStagedOnQuit(); });
}
