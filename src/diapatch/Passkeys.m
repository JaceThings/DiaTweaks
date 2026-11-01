// diapatch as a native messaging host for the Passkeys tweak. A patched Dia can't reach Apple Passwords, so each request
// runs in an unpatched copy, at the page's origin, in a window the size of the passkey sheet so the sheet covers it.
#import <AppKit/AppKit.h>
#import <spawn.h>
#import "Passkeys.h"

extern char **environ;
int responsibility_spawnattrs_setdisclaim(posix_spawnattr_t *attrs, int disclaim);  // libSystem: the helper answers for itself

static const int kSheetWidth = 480, kSheetHeight = 300;

@interface DPDevTools : NSObject
@end

@implementation DPDevTools {
    FILE *_in, *_out;
    int _nextId;
}

- (instancetype)initWithIn:(int)in out:(int)out {
    _in = fdopen(in, "r");
    _out = fdopen(out, "w");
    return self;
}

- (NSDictionary *)read {
    NSMutableData *data = [NSMutableData data];
    for (int c; (c = fgetc(_in)) != 0;) {
        if (c == EOF) return nil;
        char byte = c;
        [data appendBytes:&byte length:1];
    }
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (void)write:(NSDictionary *)message {
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    fwrite(data.bytes, 1, data.length, _out);
    fputc(0, _out);
    fflush(_out);
}

// Sends a command and waits for its answer, skipping events.
- (NSDictionary *)send:(NSString *)method params:(NSDictionary *)params session:(NSString *)session {
    int id = ++_nextId;
    NSMutableDictionary *message = [@{ @"id" : @(id), @"method" : method, @"params" : params ?: @{} } mutableCopy];
    if (session) message[@"sessionId"] = session;
    [self write:message];
    for (NSDictionary *reply; (reply = [self read]);)
        if ([reply[@"id"] intValue] == id) return reply;
    return nil;
}
@end

static NSDictionary *readMessage(void) {
    uint32_t length;
    if (fread(&length, 4, 1, stdin) != 1) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (fread(data.mutableBytes, 1, length, stdin) != length) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

static void writeMessage(NSDictionary *message) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    uint32_t length = (uint32_t)data.length;
    fwrite(&length, 4, 1, stdout);
    fwrite(data.bytes, 1, length, stdout);
    fflush(stdout);
}

static NSDictionary *failure(NSString *message) { return @{ @"error" : @{ @"name" : @"NotAllowedError", @"message" : message } }; }

static void prepareProfile(NSString *userData) {
    NSFileManager *files = NSFileManager.defaultManager;
    // The first time, it signs in with Dia's own account store instead of asking.
    if (![files fileExistsAtPath:[userData stringByAppendingPathComponent:@"global_key_value_store.db"]]) {
        NSString *dia = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Dia/User Data"];
        [files createDirectoryAtPath:userData withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSString *suffix in @[ @"", @"-wal", @"-shm" ]) {
            NSString *name = [@"global_key_value_store.db" stringByAppendingString:suffix];
            [files copyItemAtPath:[dia stringByAppendingPathComponent:name] toPath:[userData stringByAppendingPathComponent:name] error:nil];
        }
    }
    for (NSString *saved in @[ @"Default/Sessions", @"Default/Sessions_Encrypted", @"Default/tabs.db", @"Default/tabs.db-wal", @"Default/tabs.db-shm" ])  // or it reopens its last windows
        [files removeItemAtPath:[userData stringByAppendingPathComponent:saved] error:nil];
}

static pid_t launchHelper(NSString *home, int toHelper[2], int fromHelper[2]) {
    NSString *app = [home stringByAppendingPathComponent:@"pristine/Dia.app/Contents/MacOS/Dia"];
    NSString *data = [home stringByAppendingPathComponent:@"passkey-helper"];
    NSString *profile = [@"--user-data-dir=" stringByAppendingString:[data stringByAppendingPathComponent:@"ud"]];
    prepareProfile([data stringByAppendingPathComponent:@"ud/User Data"]);
    const char *argv[] = { app.fileSystemRepresentation, profile.UTF8String, "--remote-debugging-pipe", NULL };

    NSMutableArray<NSString *> *environment = [NSMutableArray array];
    for (char **e = environ; *e; e++) [environment addObject:@(*e)];
    [environment addObject:[@"CFFIXED_USER_HOME=" stringByAppendingString:data]];  // its own preferences and Application Support
    const char **envp = calloc(environment.count + 1, sizeof *envp);
    for (NSUInteger i = 0; i < environment.count; i++) envp[i] = environment[i].UTF8String;

    posix_spawn_file_actions_t files;
    posix_spawn_file_actions_init(&files);
    posix_spawn_file_actions_adddup2(&files, toHelper[0], 3);
    posix_spawn_file_actions_adddup2(&files, fromHelper[1], 4);
    posix_spawn_file_actions_addopen(&files, 0, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_addopen(&files, 1, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addopen(&files, 2, "/dev/null", O_WRONLY, 0);
    posix_spawnattr_t attrs;
    posix_spawnattr_init(&attrs);
    responsibility_spawnattrs_setdisclaim(&attrs, 1);
    pid_t pid = 0;
    int status = posix_spawn(&pid, argv[0], &files, &attrs, (char *const *)argv, (char *const *)envp);
    free(envp);
    return status == 0 ? pid : 0;
}

// The tab in the window Dia opens at launch: the only window it will have. Signed out, Dia shows its welcome window
// instead, and tabs get no window until someone signs in there.
static NSString *startupTab(DPDevTools *tools, int seconds, NSNumber **windowId) {
    for (int tries = 0; tries < seconds * 4; tries++, usleep(250000))
        for (NSDictionary *target in [tools send:@"Target.getTargets" params:nil session:nil][@"result"][@"targetInfos"]) {
            if (![target[@"type"] isEqualToString:@"page"]) continue;
            NSDictionary *window = [tools send:@"Browser.getWindowForTarget" params:@{ @"targetId" : target[@"targetId"] } session:nil][@"result"];
            if (![window[@"bounds"][@"width"] intValue]) continue;
            *windowId = window[@"windowId"];
            return target[@"targetId"];
        }
    return nil;
}

static BOOL atOrigin(DPDevTools *tools, NSString *session, NSString *origin) {
    for (int tries = 0; tries < 50; tries++, usleep(100000)) {
        NSDictionary *page = [tools send:@"Runtime.evaluate" params:@{ @"expression" : @"[location.origin, document.readyState]", @"returnByValue" : @YES } session:session];
        NSArray *state = page[@"result"][@"result"][@"value"];
        if ([state.lastObject isEqual:@"complete"]) return [state.firstObject isEqual:origin];
    }
    return NO;
}

static NSDictionary *runInHelper(DPDevTools *tools, pid_t pid, NSString *kind, NSString *origin, id options) {
    NSRunningApplication *helper = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    NSNumber *windowId;
    NSString *targetId = startupTab(tools, 15, &windowId);
    if (!targetId) {
        [helper activateWithOptions:NSApplicationActivateAllWindows];
        targetId = startupTab(tools, 600, &windowId);
    }
    if (!targetId) return failure(@"Sign in to the copy of Dia that opened, then try the passkey again.");
    CGRect screen = CGDisplayBounds(CGMainDisplayID());
    NSDictionary *bounds = @{
        @"left" : @((int)(CGRectGetMidX(screen) - kSheetWidth / 2)), @"top" : @((int)(CGRectGetMidY(screen) - kSheetHeight / 2 - 100)),
        @"width" : @(kSheetWidth), @"height" : @(kSheetHeight),
    };
    [tools send:@"Browser.setWindowBounds" params:@{ @"windowId" : windowId, @"bounds" : bounds } session:nil];

    NSString *session = [tools send:@"Target.attachToTarget" params:@{ @"targetId" : targetId, @"flatten" : @YES } session:nil][@"result"][@"sessionId"];
    // Any page at the origin will do. robots.txt runs none of the site's scripts, unless it redirects elsewhere.
    for (NSString *path in @[ @"/robots.txt", @"/" ]) {
        [tools send:@"Page.navigate" params:@{ @"url" : [origin stringByAppendingString:path] } session:session];
        if (atOrigin(tools, session, origin)) break;
    }
    [helper activateWithOptions:NSApplicationActivateAllWindows];  // or the sheet opens behind

    NSData *json = [NSJSONSerialization dataWithJSONObject:@{ @"kind" : kind, @"options" : options } options:0 error:nil];
    NSString *script = [NSString stringWithFormat:@"(async ({ kind, options }) => {"
                                                    "  try {"
                                                    "    const credential = kind === 'create'"
                                                    "      ? await navigator.credentials.create({ publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options) })"
                                                    "      : await navigator.credentials.get({ publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options) });"
                                                    "    return { credential: credential.toJSON() };"
                                                    "  } catch (e) { return { error: { name: e.name, message: e.message } }; }"
                                                    "})(%@)",
                                                   [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    NSDictionary *result = [tools send:@"Runtime.evaluate"
                                params:@{ @"expression" : script, @"awaitPromise" : @YES, @"returnByValue" : @YES, @"userGesture" : @YES }
                               session:session][@"result"][@"result"][@"value"];
    return result ?: failure(@"The passkey copy of Dia quit before answering.");
}

int DPRunPasskeyHost(NSString *home) {
    NSDictionary *request = readMessage();
    if (!request) return 1;
    int toHelper[2], fromHelper[2];
    if (pipe(toHelper) || pipe(fromHelper)) return writeMessage(failure(@"Couldn't start the passkey copy of Dia.")), 1;
    pid_t pid = launchHelper(home, toHelper, fromHelper);
    close(toHelper[0]);
    close(fromHelper[1]);
    if (!pid) return writeMessage(failure(@"Couldn't start the passkey copy of Dia.")), 1;

    DPDevTools *tools = [[DPDevTools alloc] initWithIn:fromHelper[0] out:toHelper[1]];
    writeMessage(runInHelper(tools, pid, request[@"kind"], request[@"origin"], request[@"options"]));
    [tools send:@"Browser.close" params:nil session:nil];
    for (int i = 0; i < 50 && kill(pid, 0) == 0; i++) usleep(100000);
    kill(pid, SIGKILL);
    return 0;
}
