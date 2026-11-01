#import "StdPatch/StdPatch.h"
#import <crt_externs.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>

// Patching costs Dia the entitlement Apple Passwords requires of browsers, so an extension hands each passkey request to
// diapatch, which runs it in the unpatched Dia.

extern DPPatch DPPasskeys;

static NSString *const kExtensionID = @"ljonmeeapeagnkmjklinbocjbjepecce";  // from the key in extension/manifest.json

static NSString *DPSupportPath(NSString *name) {
    return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"DiaPatches"] stringByAppendingPathComponent:name];
}

static BOOL DPWriteExtension(NSString *folder) {
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in @[ @"manifest.json", @"page.js", @"bridge.js", @"worker.js" ]) {
        NSString *section = [@"__pk_" stringByAppendingString:name.stringByDeletingPathExtension];
        unsigned long size = 0;
        uint8_t *bytes = getsectiondata(&_mh_dylib_header, "__TEXT", section.UTF8String, &size);
        if (!bytes || ![[NSData dataWithBytes:bytes length:size] writeToFile:[folder stringByAppendingPathComponent:name] atomically:YES]) return NO;
    }
    return YES;
}

// Dia's Chromium looks for native messaging hosts in Chrome's folder.
static BOOL DPRegisterHost(void) {
    NSString *folder = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"Google/Chrome/NativeMessagingHosts"];
    NSDictionary *manifest = @{
        @"name" : @"com.diapatches.passkeys",
        @"description" : @"DiaTweaks passkeys",
        @"path" : DPSupportPath(@"bin/diapatch"),
        @"type" : @"stdio",
        @"allowed_origins" : @[ [NSString stringWithFormat:@"chrome-extension://%@/", kExtensionID] ],
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:nil];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    return [json writeToFile:[folder stringByAppendingPathComponent:@"com.diapatches.passkeys.json"] atomically:YES];
}

// Chromium only reads the command line Dia started with, so Dia restarts in place with the extension added.
static void DPLoadExtension(NSString *folder) {
    const char *flag = [@"--load-extension=" stringByAppendingString:folder].fileSystemRepresentation;
    int argc = *_NSGetArgc();
    char **argv = *_NSGetArgv();
    for (int i = 1; i < argc; i++) if (!strcmp(argv[i], flag)) return;
    char **next = calloc(argc + 2, sizeof *next);
    memcpy(next, argv, argc * sizeof *next);
    next[argc] = (char *)flag;
    char path[PATH_MAX];
    uint32_t size = sizeof path;
    if (_NSGetExecutablePath(path, &size) == 0) execv(path, next);
    free(next);
}

static void DPShowHelper(NSNotification *note) {
    if ([note.name hasSuffix:@"signIn"]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Sign in to Dia once for passkeys";
        alert.informativeText = @"Passkeys from Apple Passwords open in a second copy of Dia, and it needs you to sign in once. "
                                 "Its intro plays first: press Skip Intro in the bottom right, then sign in with your Dia email. "
                                 "Your passkey carries on after.";
        [alert runModal];
    }
    [[NSRunningApplication runningApplicationWithProcessIdentifier:[note.object intValue]] activateFromApplication:NSRunningApplication.currentApplication
                                                                                                         options:NSApplicationActivateAllWindows];
}

static void DPInstallPasskeys(void) {
    if (!DPPasskeys.on) return;
    NSString *extension = DPSupportPath(@"passkeys-extension");
    if (!DPWriteExtension(extension) || !DPRegisterHost()) return (void)NSLog(@"DiaPatches: couldn't set up passkeys");
    DPLoadExtension(extension);
    for (NSString *name in @[ @"com.diapatches.passkeys.show", @"com.diapatches.passkeys.signIn" ])
        [NSDistributedNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DPShowHelper(note); }];
}

DP_PATCH(DPPasskeys) {
    .key = @"passkeys",
    .order = 100,
    .title = @"Apple Passwords passkeys",
    .detail = @"Sign in with passkeys saved in Apple Passwords. A second copy of Dia opens behind the Touch ID prompt and quits after. Takes effect when Dia relaunches. Experimental.",
    .symbol = @"person.badge.key.fill",
    .tint = @"systemGreenColor",
    .section = @"Passwords",
    .install = DPInstallPasskeys,
};
