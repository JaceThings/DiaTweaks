// Dia updates go through the diapatch CLI, which re-patches each new Dia before it's installed.
#import "StdPatch/StdPatch.h"

void DPInstallUpdates(void);
void DPRunCLI(NSArray<NSString *> *args, void (^completion)(NSString *output));
void DPCheckForUpdates(void (^completion)(NSDictionary *status));
NSString *DPPendingUpdate(NSDictionary *status);  // What relaunching installs, or nil.
BOOL DPAutoUpdates(void);
void DPSetAutoUpdates(BOOL on);
void DPHandOffAndQuit(NSString *command);  // Quits Dia while the CLI runs `command`, then relaunches it.
