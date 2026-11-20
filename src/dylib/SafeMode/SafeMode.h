#import "StdPatch/StdPatch.h"

extern NSInteger DPSafeMode;
extern BOOL DPPaused;  // Every tweak is off and keeps its settings until the pause file goes.
void DPBeginLaunch(void);
void DPLeaveSafeMode(void);
BOOL DPPauseSaved(void);
void DPSetPaused(BOOL paused);
