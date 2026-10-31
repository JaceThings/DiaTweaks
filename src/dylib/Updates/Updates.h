// Dia and DiaTweaks updates go through the diapatch CLI: `check` finds them, `update` and `self-update` download
// and stage them, and `apply` installs what's staged while Dia is quit.
#import "StdPatch/StdPatch.h"

void DPInstallUpdates(void);
void DPRunCLI(NSArray<NSString *> *args, void (^completion)(NSString *output));
void DPHandOffAndQuit(NSArray<NSString *> *args);  // Quits Dia while the CLI runs `args`, then relaunches it.

// The two things that update. Each is a key in `diapatch check --json`.
extern NSString *const DPDia, *const DPTweaks;

// How far each part updates on its own. Each level does what the one before it does too.
typedef NS_ENUM(NSInteger, DPAutoLevel) { DPAutoOff, DPAutoNotify, DPAutoDownload, DPAutoInstall };
DPAutoLevel DPAutoLevelOf(NSString *part);  // DPAutoInstall unless changed
void DPSetAutoLevel(NSString *part, DPAutoLevel level);

extern NSNotificationName const DPUpdatesDidChangeNotification;

@interface DPUpdates : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) NSDictionary *found;  // The last check, nil before one finishes.
@property (nonatomic, readonly) BOOL checking;
- (void)check;
- (void)check:(void (^)(void))done;
- (BOOL)available:(NSString *)part;
- (BOOL)staged:(NSString *)part;
- (BOOL)downloading:(NSString *)part;
- (BOOL)failed:(NSString *)part;  // The last download of it didn't work.
- (double)progress:(NSString *)part;  // 0–1 while downloading, then -1 while it's checked and prepared.
- (void)download:(NSString *)part;
- (void)download:(NSString *)part then:(void (^)(void))done;
- (void)installAndRelaunch:(NSArray<NSString *> *)parts;
@end
