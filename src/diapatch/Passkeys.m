#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <pthread.h>
#import <spawn.h>
#import <sys/file.h>
#import <sys/wait.h>
#import "LaunchServices.h"
#import "Passkeys.h"

extern char **environ;
int responsibility_spawnattrs_setdisclaim(posix_spawnattr_t *attrs, int disclaim);  // private: macOS asks about the copy, not Dia

static const int kSheetWidth = 480, kSheetHeight = 300;
static const uint32_t kMaxMessageLength = 1024 * 1024;
static const NSUInteger kMaxHelperMessageLength = 16 * 1024 * 1024;

static FILE *gFromHelper, *gToHelper;
static _Atomic pid_t gHelper;
static _Atomic int gCancelled;

static NSDictionary *readFromHelper(void) {
    if (!gFromHelper) return nil;
    NSMutableData *data = [NSMutableData data];
    for (int c; (c = fgetc(gFromHelper)) != 0;) {
        if (c == EOF || data.length >= kMaxHelperMessageLength) return nil;
        [data appendBytes:&(char){ c } length:1];
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

static NSDictionary *send(NSString *method, NSDictionary *params, NSString *session) {
    if (!gToHelper || !gFromHelper || !method) return nil;
    static int lastId;
    int id = ++lastId;
    NSMutableDictionary *message = [@{ @"id" : @(id), @"method" : method, @"params" : params ?: @{} } mutableCopy];
    message[@"sessionId"] = session;
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    if (!data) return nil;
    fwrite(data.bytes, 1, data.length, gToHelper);
    fputc(0, gToHelper);
    fflush(gToHelper);
    for (NSDictionary *reply; (reply = readFromHelper());)
        if ([reply[@"id"] intValue] == id) return reply;
    return nil;
}

static id evaluate(NSString *session, NSString *expression) {
    if (!expression) return nil;
    NSDictionary *params = @{ @"expression" : expression, @"awaitPromise" : @YES, @"returnByValue" : @YES, @"userGesture" : @YES };
    NSDictionary *reply = send(@"Runtime.evaluate", params, session);
    NSDictionary *outer = [reply[@"result"] isKindOfClass:NSDictionary.class] ? reply[@"result"] : nil;
    NSDictionary *inner = [outer[@"result"] isKindOfClass:NSDictionary.class] ? outer[@"result"] : nil;
    return inner[@"value"];
}

static NSDictionary *readMessageFrom(FILE *stream) {
    uint32_t length = 0;
    if (!stream || fread(&length, sizeof length, 1, stream) != 1 || !length || length > kMaxMessageLength) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (!data || fread(data.mutableBytes, 1, length, stream) != length) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

static NSDictionary *readMessage(void) { return readMessageFrom(stdin); }

static BOOL validRequest(NSDictionary *request) {
    if (![request isKindOfClass:NSDictionary.class]) return NO;
    id kind = request[@"kind"], origin = request[@"origin"], options = request[@"options"];
    return ([kind isEqual:@"create"] || [kind isEqual:@"get"])
        && [origin isKindOfClass:NSString.class] && [origin length] > 0
        && [options isKindOfClass:NSDictionary.class]
        && [NSJSONSerialization isValidJSONObject:options];
}

static void writeMessage(NSDictionary *message) {
    if (!message) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    if (!data) return;
    uint32_t length = (uint32_t)data.length;
    fwrite(&length, 4, 1, stdout);
    fwrite(data.bytes, 1, length, stdout);
    fflush(stdout);
}

static NSDictionary *failure(NSString *message) { return @{ @"error" : @{ @"name" : @"NotAllowedError", @"message" : message } }; }

// The extension holds our stdin open until it has the answer, so EOF means the page gave up.
static void *watchForCancel(void *_) {
    char byte;
    while (read(STDIN_FILENO, &byte, 1) > 0) {}
    gCancelled = 1;
    pid_t helper = gHelper;
    if (helper <= 0) return NULL;
    kill(helper, SIGTERM);
    for (int i = 0; i < 30 && gHelper == helper; i++) usleep(100000);
    if (gHelper == helper) kill(helper, SIGKILL);
    return NULL;
}

static NSArray<NSString *> *const kAccountStore = @[ @"global_key_value_store.db", @"global_key_value_store.db-wal", @"global_key_value_store.db-shm" ];

static NSArray *modificationDates(NSString *folder) {
    NSMutableArray *dates = [NSMutableArray array];
    for (NSString *name in kAccountStore)
        [dates addObject:[NSFileManager.defaultManager attributesOfItemAtPath:[folder stringByAppendingPathComponent:name] error:nil].fileModificationDate ?: NSNull.null];
    return dates;
}

// Dia may be writing its account store: copy until the files hold still.
static void signInAsDia(NSString *userData) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *dia = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Dia/User Data"];
    [files createDirectoryAtPath:userData withIntermediateDirectories:YES attributes:nil error:nil];
    for (int tries = 0; tries < 5; tries++) {
        NSArray *before = modificationDates(dia);
        for (NSString *name in kAccountStore) {
            [files removeItemAtPath:[userData stringByAppendingPathComponent:name] error:nil];
            [files copyItemAtPath:[dia stringByAppendingPathComponent:name] toPath:[userData stringByAppendingPathComponent:name] error:nil];
        }
        if ([modificationDates(dia) isEqual:before]) return;
    }
}

static void skipIntro(NSString *data) {
    NSString *preferences = [data stringByAppendingPathComponent:@"Library/Preferences/company.thebrowser.dia"];
    [[NSTask launchedTaskWithLaunchPath:@"/usr/bin/defaults" arguments:@[ @"write", preferences, @"hasPresentedOnboardingIntro", @"-bool", @"YES" ]] waitUntilExit];
}

static void forgetWindows(NSString *userData) {
    for (NSString *saved in @[ @"Sessions", @"Sessions_Encrypted", @"tabs.db", @"tabs.db-wal", @"tabs.db-shm" ])
        [NSFileManager.defaultManager removeItemAtPath:[userData stringByAppendingPathComponent:[@"Default" stringByAppendingPathComponent:saved]] error:nil];
}

static NSDictionary *sheetBounds(void) {
    CGRect screen = CGDisplayBounds(CGMainDisplayID());
    return @{
        @"left" : @((int)(CGRectGetMidX(screen) - kSheetWidth / 2)), @"top" : @((int)(CGRectGetMidY(screen) - kSheetHeight / 2 - 100)),
        @"width" : @(kSheetWidth), @"height" : @(kSheetHeight),
    };
}

static pid_t launchHelper(NSString *home, int toHelper[2], int fromHelper[2]) {
    NSString *data = [home stringByAppendingPathComponent:@"passkey-helper"];
    NSString *userData = [data stringByAppendingPathComponent:@"ud/User Data"];
    signInAsDia(userData);
    skipIntro(data);
    forgetWindows(userData);

    NSString *app = [home stringByAppendingPathComponent:@"pristine/Dia.app/Contents/MacOS/Dia"];
    NSString *profile = [@"--user-data-dir=" stringByAppendingString:[data stringByAppendingPathComponent:@"ud"]];
    NSDictionary *bounds = sheetBounds();
    NSString *size = [NSString stringWithFormat:@"--window-size=%@,%@", bounds[@"width"], bounds[@"height"]];
    NSString *position = [NSString stringWithFormat:@"--window-position=%@,%@", bounds[@"left"], bounds[@"top"]];
    // Disable sync so the helper's empty profile doesn't wipe the user's synced tabs, favorites, and extensions.
    const char *argv[] = { app.fileSystemRepresentation, profile.UTF8String, size.UTF8String, position.UTF8String, "--remote-debugging-pipe", "--mute-audio",
                           "-transientFeatureFlagOverrides", "sync-enabled=false", NULL };

    NSString *fixedHome = [@"CFFIXED_USER_HOME=" stringByAppendingString:data];
    size_t envCount = 0;
    while (environ[envCount]) envCount++;
    const char **envp = calloc(envCount + 2, sizeof *envp);
    if (!envp) return 0;
    memcpy(envp, environ, envCount * sizeof *envp);
    envp[envCount] = fixedHome.UTF8String;

    posix_spawn_file_actions_t files;
    posix_spawn_file_actions_init(&files);
    posix_spawn_file_actions_adddup2(&files, toHelper[0], 3);
    posix_spawn_file_actions_adddup2(&files, fromHelper[1], 4);
    posix_spawn_file_actions_addopen(&files, 0, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_addopen(&files, 1, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addopen(&files, 2, "/dev/null", O_WRONLY, 0);
    posix_spawnattr_t attrs;
    posix_spawnattr_init(&attrs);
    posix_spawnattr_setflags(&attrs, POSIX_SPAWN_CLOEXEC_DEFAULT);
    responsibility_spawnattrs_setdisclaim(&attrs, 1);
    pid_t pid = 0;
    int status = posix_spawn(&pid, argv[0], &files, &attrs, (char *const *)argv, (char *const *)envp);
    posix_spawn_file_actions_destroy(&files);
    posix_spawnattr_destroy(&attrs);
    free(envp);
    return status == 0 ? pid : 0;
}

static BOOL hasWindowOnScreen(pid_t pid) {
    NSArray *windows = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
    for (NSDictionary *window in windows)
        if ([window[(id)kCGWindowOwnerPID] intValue] == pid && [window[(id)kCGWindowLayer] intValue] == 0) return YES;
    return NO;
}

typedef NS_ENUM(int, DPStartup) { DPStartupReady, DPStartupSignedOut, DPStartupFailed };

static DPStartup waitForStartupTab(pid_t pid, int seconds, NSString **targetId, NSNumber **windowId) {
    for (int tries = 0, tablessWindow = 0; tries < seconds * 4; tries++, usleep(250000)) {
        NSDictionary *targets = send(@"Target.getTargets", nil, nil);
        if (!targets) return DPStartupFailed;
        NSDictionary *result = [targets[@"result"] isKindOfClass:NSDictionary.class] ? targets[@"result"] : nil;
        NSArray *infos = [result[@"targetInfos"] isKindOfClass:NSArray.class] ? result[@"targetInfos"] : nil;
        for (NSDictionary *target in infos) {
            if (![target isKindOfClass:NSDictionary.class] || ![target[@"type"] isEqual:@"page"]) continue;
            NSString *tid = [target[@"targetId"] isKindOfClass:NSString.class] ? target[@"targetId"] : nil;
            if (!tid) continue;
            NSDictionary *reply = send(@"Browser.getWindowForTarget", @{ @"targetId" : tid }, nil);
            NSDictionary *window = [reply[@"result"] isKindOfClass:NSDictionary.class] ? reply[@"result"] : nil;
            NSDictionary *bounds = [window[@"bounds"] isKindOfClass:NSDictionary.class] ? window[@"bounds"] : nil;
            if (![bounds[@"width"] intValue] || !window[@"windowId"]) continue;
            *targetId = tid;
            *windowId = window[@"windowId"];
            return DPStartupReady;
        }
        tablessWindow = hasWindowOnScreen(pid) ? tablessWindow + 1 : 0;
        if (tablessWindow == 8) return DPStartupSignedOut;
    }
    return DPStartupFailed;
}

static NSString *page(NSString *title, NSString *detail) {
    NSString *html = [NSString stringWithFormat:
        @"<!doctype html><meta name=color-scheme content='light dark'><title>Passkey</title>"
         "<style>html,body{height:100%%;margin:0}body{display:grid;place-items:center;text-align:center;font:13px -apple-system,sans-serif;"
         "background:Canvas;color:CanvasText}b{display:block;font-size:15px;margin-bottom:6px}p{margin:0;opacity:.6}</style>"
         "<div><b>%@</b><p>%@</p></div>", title, detail];
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[ html ] options:0 error:nil];
    return [NSString stringWithFormat:@"document.open(); document.write(%@[0].replace('{site}', location.host)); document.close()",
                                      [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
}

static BOOL atOrigin(NSString *session, NSString *origin) {
    for (int tries = 0; tries < 50; tries++, usleep(100000)) {
        NSArray *state = evaluate(session, @"[location.origin, document.readyState]");
        if ([state isKindOfClass:NSArray.class] && state.count == 2 && [state.lastObject isEqual:@"complete"])
            return [state.firstObject isEqual:origin];
    }
    return NO;
}

// Only the frontmost app can bring another forward, and that's Dia.
static void tellDia(NSString *what, pid_t helper) {
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:[@"com.diapatches.passkeys." stringByAppendingString:what]
                                                                 object:@(helper).stringValue
                                                               userInfo:nil
                                                     deliverImmediately:YES];
}

static NSDictionary *runInHelper(pid_t pid, NSString *kind, NSString *origin, id options) {
    if (![kind isKindOfClass:NSString.class] || ![origin isKindOfClass:NSString.class] || ![options isKindOfClass:NSDictionary.class])
        return failure(@"Invalid passkey request.");
    NSString *targetId;
    NSNumber *windowId;
    DPStartup startup = waitForStartupTab(pid, 60, &targetId, &windowId);
    if (startup == DPStartupSignedOut) {
        tellDia(@"signIn", pid);
        startup = waitForStartupTab(pid, 600, &targetId, &windowId);
    }
    if (startup != DPStartupReady || !targetId || !windowId) return failure(@"The passkey copy of Dia didn't open.");

    send(@"Browser.setWindowBounds", @{ @"windowId" : windowId, @"bounds" : sheetBounds() }, nil);
    NSDictionary *attached = send(@"Target.attachToTarget", @{ @"targetId" : targetId, @"flatten" : @YES }, nil);
    NSDictionary *attachedResult = [attached[@"result"] isKindOfClass:NSDictionary.class] ? attached[@"result"] : nil;
    NSString *session = [attachedResult[@"sessionId"] isKindOfClass:NSString.class] ? attachedResult[@"sessionId"] : nil;
    if (!session) return failure(@"Couldn't connect to the passkey copy of Dia.");
    // robots.txt runs none of the site's scripts.
    for (NSString *path in @[ @"/robots.txt", @"/" ]) {
        send(@"Page.navigate", @{ @"url" : [origin stringByAppendingString:path] }, session);
        if (atOrigin(session, origin)) break;
    }
    evaluate(session, page(@"Use your passkey for {site}", @"DiaTweaks opened this window to reach Apple Passwords. It closes by itself."));
    tellDia(@"show", pid);
    // WebAuthn refuses an unfocused page, and focus comes once Dia has brought the copy forward.
    for (int tries = 0; tries < 30; tries++, usleep(100000))
        if ([evaluate(session, @"document.hasFocus()") boolValue]) break;

    NSData *json = [NSJSONSerialization dataWithJSONObject:@{ @"kind" : kind, @"options" : options } options:0 error:nil];
    if (!json) return failure(@"Invalid passkey request.");
    NSString *script = [NSString stringWithFormat:@"(async ({ kind, options }) => {"
                                                    "  const signal = AbortSignal.timeout(Math.min(options.timeout || 300000, 600000));"
                                                    "  try {"
                                                    "    const credential = kind === 'create'"
                                                    "      ? await navigator.credentials.create({ publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options), signal })"
                                                    "      : await navigator.credentials.get({ publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options), signal });"
                                                    "    return { credential: credential.toJSON() };"
                                                    "  } catch (e) { return { error: { name: e.name === 'TimeoutError' ? 'NotAllowedError' : e.name, message: e.message } }; }"
                                                    "})(%@)",
                                                   [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    id result = evaluate(session, script);
    if (![result isKindOfClass:NSDictionary.class]) return failure(@"The passkey copy of Dia quit before answering.");
    if (result[@"credential"]) evaluate(session, page(@"Done", @"This window closes in a moment. Thanks for waiting."));
    return result;
}

static void closePair(int fds[2]) {
    for (int i = 0; i < 2; i++) {
        if (fds[i] >= 0) close(fds[i]);
        fds[i] = -1;
    }
}

static int openPasskeyLock(NSString *home) {
    if (!home.length) return -1;
    if (![NSFileManager.defaultManager createDirectoryAtPath:home withIntermediateDirectories:YES attributes:nil error:nil]) return -1;
    return open([home stringByAppendingPathComponent:@"passkey-helper.lock"].fileSystemRepresentation, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
}

static BOOL lockPasskeyHelper(int lock) {
    while (flock(lock, LOCK_EX | LOCK_NB) != 0) {
        if (errno == EINTR) continue;
        if (errno != EWOULDBLOCK || gCancelled) return NO;
        usleep(50000);
    }
    return !gCancelled;
}

int DPRunPasskeyHost(NSString *home) {
    NSDictionary *request = readMessage();
    if (!validRequest(request)) return 1;
    pthread_t watcher;
    if (pthread_create(&watcher, NULL, watchForCancel, NULL) == 0) pthread_detach(watcher);

    int lock = openPasskeyLock(home);
    if (lock < 0) return writeMessage(failure(@"Couldn't open the passkey lock file.")), 1;
    if (!lockPasskeyHelper(lock)) {
        close(lock);
        if (gCancelled) return writeMessage(failure(@"The passkey request was cancelled.")), 0;
        return writeMessage(failure(@"Couldn't lock the passkey helper.")), 1;
    }

    int toHelper[2] = { -1, -1 }, fromHelper[2] = { -1, -1 };
    pid_t pid = 0;
    if (pipe(toHelper) != 0 || pipe(fromHelper) != 0 || !(pid = launchHelper(home, toHelper, fromHelper))) {
        closePair(toHelper);
        closePair(fromHelper);
        close(lock);
        return writeMessage(failure(@"Couldn't start the passkey copy of Dia.")), 1;
    }
    gHelper = pid;
    if (gCancelled) kill(pid, SIGTERM);
    close(toHelper[0]), toHelper[0] = -1;
    close(fromHelper[1]), fromHelper[1] = -1;

    gFromHelper = fdopen(fromHelper[0], "r");
    if (gFromHelper) fromHelper[0] = -1;
    gToHelper = fdopen(toHelper[1], "w");
    if (gToHelper) toHelper[1] = -1;
    if (!gFromHelper || !gToHelper) {
        if (gFromHelper) fclose(gFromHelper), gFromHelper = NULL;
        if (gToHelper) fclose(gToHelper), gToHelper = NULL;
        closePair(toHelper);
        closePair(fromHelper);
        gHelper = 0;
        kill(pid, SIGKILL);
        waitpid(pid, NULL, 0);
        close(lock);
        return writeMessage(failure(@"Couldn't connect to the passkey copy of Dia.")), 1;
    }

    NSDictionary *result = runInHelper(pid, request[@"kind"], request[@"origin"], request[@"options"]);
    // Dia kills this process once it has the answer, so the copy has to quit before then.
    send(@"Browser.close", nil, nil);
    BOOL exited = NO;
    for (int i = 0; i < 50 && !(exited = waitpid(pid, NULL, WNOHANG) != 0); i++) usleep(100000);
    gHelper = 0;
    if (!exited) {
        kill(pid, SIGKILL);
        waitpid(pid, NULL, 0);
    }
    fclose(gFromHelper), gFromHelper = NULL;
    fclose(gToHelper), gToHelper = NULL;
    close(lock);
    DPForgetApp([home stringByAppendingPathComponent:@"pristine/Dia.app"]);
    writeMessage(result);
    return 0;
}
