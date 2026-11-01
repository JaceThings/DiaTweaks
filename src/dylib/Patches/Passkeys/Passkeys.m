#import "StdPatch/StdPatch.h"
#import <crt_externs.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>

// Patched, Dia loses the entitlement Apple Passwords asks of browsers. An extension (extension/, built into this dylib)
// hands each page's passkey request to diapatch, which runs it in the unpatched copy kept in pristine/.

extern DPPatch DPPasskeys;

static NSString *const kExtensionID = @"ljonmeeapeagnkmjklinbocjbjepecce";

static NSString *DPSupportPath(NSString *name) {
    return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"DiaPatches"] stringByAppendingPathComponent:name];
}

static BOOL DPWriteExtension(NSString *folder) {
    NSDictionary<NSString *, NSString *> *files = @{
        @"manifest.json" : @"__pk_manifest", @"page.js" : @"__pk_page", @"bridge.js" : @"__pk_bridge", @"worker.js" : @"__pk_worker",
    };
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in files) {
        unsigned long size = 0;
        uint8_t *bytes = getsectiondata(&_mh_dylib_header, "__TEXT", files[name].UTF8String, &size);
        if (!bytes || ![[NSData dataWithBytes:bytes length:size] writeToFile:[folder stringByAppendingPathComponent:name] atomically:YES]) return NO;
    }
    return YES;
}

// Tells Dia it may start diapatch for the extension. Dia's Chromium looks for hosts where Chrome's do.
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

// Dia's Chromium reads the command line it was started with, so Dia starts again in place, this time with the extension.
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

// diapatch can't bring the copy forward itself: macOS lets only the app in front do that, which is Dia while you sign in.
static void DPShowHelper(NSNotification *note) {
    NSRunningApplication *helper = [NSRunningApplication runningApplicationWithProcessIdentifier:[note.object intValue]];
    if ([note.name hasSuffix:@"signIn"]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Sign in to Dia once for passkeys";
        alert.informativeText = @"Passkeys from Apple Passwords open in a second copy of Dia, and it needs you to sign in once. "
                                 "Its intro plays first: press Skip Intro in the bottom right, then sign in with your Dia email. "
                                 "Your passkey carries on after.";
        [alert runModal];
    }
    [helper activateFromApplication:NSRunningApplication.currentApplication options:NSApplicationActivateAllWindows];
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
