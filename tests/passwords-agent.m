#import <Foundation/Foundation.h>
static NSString *testHome;
static NSString *DPTestHome(void) { return testHome; }
static NSMutableArray<NSArray *> *calls;
static BOOL loaded;
@interface FixtureTask : NSObject
@property NSURL *executableURL;
@property NSArray *arguments;
@property id standardOutput, standardError;
@property int terminationStatus;
- (BOOL)launchAndReturnError:(NSError **)error;
- (void)waitUntilExit;
@end
@implementation FixtureTask
- (BOOL)launchAndReturnError:(NSError **)error {
    NSCAssert([self.executableURL.path isEqual:@"/bin/launchctl"], @"fixture must not run external commands");
    [calls addObject:self.arguments];
    NSString *verb = self.arguments.firstObject;
    self.terminationStatus = 0;
    if ([verb isEqual:@"bootout"]) loaded = NO;
    if ([verb isEqual:@"bootstrap"]) loaded = YES;
    if ([verb isEqual:@"print"]) self.terminationStatus = loaded ? 0 : 1;
    [((NSPipe *)self.standardOutput).fileHandleForWriting closeFile];
    return YES;
}
- (void)waitUntilExit {}
@end
#define NSHomeDirectory DPTestHome
#define NSTask FixtureTask
#define main diapatchMain
#import "../src/diapatch/main.m"
#undef main
#undef NSTask
#undef NSHomeDirectory
int main(void) { @autoreleasepool {
    testHome = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    gHome = [testHome stringByAppendingPathComponent:@"support"];
    gApp = [testHome stringByAppendingPathComponent:@"Dia.app"];
    gStaged = [gHome stringByAppendingPathComponent:@"staged/Dia.app"];
    gStagedTweaks = [gHome stringByAppendingPathComponent:@"staged/DiaTweaks"];
    calls = [NSMutableArray array]; unsetenv("DIAPATCH_NO_AGENT");
    NSCAssert(applyChosen(NO, YES), @"applying tweaks must repair missing registration even without a staged bundle");
    NSCAssert(loaded && [NSFileManager.defaultManager fileExistsAtPath:agentPlist()], @"relay must be registered");
    NSUInteger count = calls.count;
    NSCAssert(ensureAgent(), @"existing correct registration should be reused");
    NSCAssert(calls.count == count + 1 && [calls.lastObject.firstObject isEqual:@"print"], @"do not restart a healthy relay");
    loaded = NO;
    NSCAssert(ensureAgent() && loaded, @"an existing plist with an unloaded job must be repaired");
    setenv("DIAPATCH_NO_AGENT", "1", 1); count = calls.count;
    NSCAssert(applyChosen(YES, NO) && ensureAgent() && calls.count == count, @"scratch installs must not touch launchd");
    [NSFileManager.defaultManager removeItemAtPath:testHome error:nil];
    puts("ok: update registration, old-release repair, unloaded jobs, idempotence and scratch opt-out");
} }
