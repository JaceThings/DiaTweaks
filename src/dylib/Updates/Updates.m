#import "Updates/Updates.h"

NSString *const DPDia = @"dia", *const DPTweaks = @"tweaks";
NSNotificationName const DPUpdatesDidChangeNotification = @"DPUpdatesDidChange";

static NSString *DPSupport(NSString *name) {
    return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"DiaPatches"] stringByAppendingPathComponent:name];
}

static NSString *DPCLI(void) { return DPSupport(@"bin/diapatch"); }

static NSUserDefaults *DPUpdateDefaults(void) { return [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; }

static NSString *DPAutoKey(NSString *part) { return [part isEqual:DPDia] ? @"autoUpdateDia" : @"autoUpdateTweaks"; }

DPAutoLevel DPAutoLevelOf(NSString *part) {
    id level = [DPUpdateDefaults() objectForKey:DPAutoKey(part)];
    return level ? MIN(MAX([level integerValue], DPAutoOff), DPAutoInstall) : DPAutoInstall;
}

void DPSetAutoLevel(NSString *part, DPAutoLevel level) { [DPUpdateDefaults() setInteger:level forKey:DPAutoKey(part)]; }

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

void DPHandOffAndQuit(NSArray<NSString *> *args) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:DPCLI()];
    task.arguments = [args arrayByAddingObjectsFromArray:@[@"--wait", @(getpid()).stringValue, @"--relaunch"]];
    if ([task launchAndReturnError:nil]) [NSApp terminate:nil];
}

@implementation DPUpdates {
    NSMutableDictionary<NSString *, NSMutableArray *> *_downloads;  // part → blocks to run when it's done
    NSMutableArray *_checked;
    NSMutableSet<NSString *> *_failed;
    NSTimer *_progress;
}

+ (instancetype)shared {
    static DPUpdates *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [DPUpdates new]; });
    return shared;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _downloads = [NSMutableDictionary new];
    _checked = [NSMutableArray new];
    _failed = [NSMutableSet new];
    return self;
}

- (void)changed { [NSNotificationCenter.defaultCenter postNotificationName:DPUpdatesDidChangeNotification object:self]; }

- (void)check:(void (^)(void))done {
    if (done) [_checked addObject:done];
    if (_checking) return;
    _checking = YES;
    [self changed];
    DPRunCLI(@[@"check", @"--json"], ^(NSString *output) {
        id found = output ? [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
        self->_found = [found isKindOfClass:NSDictionary.class] ? found : nil;
        self->_checking = NO;
        NSArray *waiting = [self->_checked copy];
        [self->_checked removeAllObjects];
        [self changed];
        for (void (^block)(void) in waiting) block();
    });
}

- (void)check { [self check:nil]; }

- (BOOL)available:(NSString *)part { return [self.found[part][@"available"] boolValue]; }
- (BOOL)staged:(NSString *)part { return [self.found[part][@"staged"] isKindOfClass:NSString.class]; }
- (BOOL)downloading:(NSString *)part { return _downloads[part] != nil; }
- (BOOL)failed:(NSString *)part { return [_failed containsObject:part]; }

- (double)progress:(NSString *)part {
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"DiaPatches"] stringByAppendingPathComponent:[part isEqual:DPDia] ? @"download/Dia.zip" : @"release/DiaTweaks.zip"];
    double size = [self.found[part][@"size"] doubleValue];
    double got = [[NSFileManager.defaultManager attributesOfItemAtPath:file error:nil][NSFileSize] doubleValue];
    return size > 0 && got < size ? got / size : got > 0 ? -1 : 0;
}

- (void)download:(NSString *)part then:(void (^)(void))done {
    if (_downloads[part]) {
        if (done) [_downloads[part] addObject:done];
        return;
    }
    _downloads[part] = done ? [NSMutableArray arrayWithObject:done] : [NSMutableArray new];
    [_failed removeObject:part];
    if (!_progress) _progress = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *_) { [self changed]; }];
    [self changed];
    DPRunCLI(@[[part isEqual:DPDia] ? @"update" : @"self-update"], ^(NSString *output) {
        if (!output) [self->_failed addObject:part];
        NSArray *waiting = self->_downloads[part];
        [self->_downloads removeObjectForKey:part];
        if (!self->_downloads.count) {
            [self->_progress invalidate];
            self->_progress = nil;
        }
        [self check:^{ for (void (^block)(void) in waiting) block(); }];
    });
}

- (void)download:(NSString *)part { [self download:part then:nil]; }

- (void)installAndRelaunch:(NSArray<NSString *> *)parts {
    NSMutableArray *args = [NSMutableArray arrayWithObject:@"apply"];
    for (NSString *part in parts) [args addObject:[part isEqual:DPDia] ? @"--dia" : @"--tweaks"];
    DPHandOffAndQuit(args);
}
@end

static void DPShowUpdateAlert(void) {
    DPUpdates *updates = DPUpdates.shared;
    [updates check:^{
        NSMutableArray<NSString *> *parts = [NSMutableArray new], *names = [NSMutableArray new];
        for (NSString *part in @[DPDia, DPTweaks]) {
            if (![updates available:part] && ![updates staged:part]) continue;
            [parts addObject:part];
            [names addObject:[NSString stringWithFormat:@"%@ %@", [part isEqual:DPDia] ? @"Dia" : @"DiaTweaks", updates.found[part][@"latest"]]];
        }
        NSAlert *alert = [NSAlert new];
        if (!parts.count) {
            alert.messageText = updates.found ? @"Dia and DiaTweaks are up to date" : @"Couldn’t check for updates";
            [alert runModal];
            return;
        }
        alert.messageText = [[names componentsJoinedByString:@" and "] stringByAppendingString:@" available"];
        alert.informativeText = @"Dia relaunches to install it once it’s downloaded.";
        [alert addButtonWithTitle:@"Update and Relaunch"];
        [alert addButtonWithTitle:@"Later"];
        if ([alert runModal] != NSAlertFirstButtonReturn) return;
        __block NSUInteger left = parts.count;
        for (NSString *part in parts)
            [updates download:part then:^{ if (--left == 0) [updates installAndRelaunch:parts]; }];
    }];
}

static void DPInstallOnQuit(void) {
    BOOL dia = DPAutoLevelOf(DPDia) == DPAutoInstall && [NSFileManager.defaultManager fileExistsAtPath:DPSupport(@"staged/Dia.app")];
    BOOL tweaks = DPAutoLevelOf(DPTweaks) == DPAutoInstall && [NSFileManager.defaultManager fileExistsAtPath:DPSupport(@"staged/DiaTweaks")];
    if (!dia && !tweaks) return;
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"apply", @"--wait", @(getpid()).stringValue, nil];
    if (dia) [args addObject:@"--dia"];
    if (tweaks) [args addObject:@"--tweaks"];
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:DPCLI()];
    task.arguments = args;
    [task launchAndReturnError:nil];
}

void DPInstallUpdates(void) {
    DPOnLaunch(^{
        DPOnMenuItem(nil, @"Check for Updates", ^{ DPShowUpdateAlert(); });
        if (DPAutoLevelOf(DPDia) == DPAutoOff && DPAutoLevelOf(DPTweaks) == DPAutoOff) return;
        DPUpdates *updates = DPUpdates.shared;
        [updates check:^{
            for (NSString *part in @[DPDia, DPTweaks])
                if (DPAutoLevelOf(part) >= DPAutoDownload && [updates available:part]) [updates download:part];
        }];
    });
    DPOnQuit(^{ DPInstallOnQuit(); });
}
