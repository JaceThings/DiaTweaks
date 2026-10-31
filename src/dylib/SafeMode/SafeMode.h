// Turns patches off when Dia keeps dying right after launch.
#import "StdPatch/StdPatch.h"

// 0: normal. 1: Dia died twice right after launching, so no patch or command hooks. 2: it kept dying, so nothing at all.
extern NSInteger DPSafeMode;
void DPBeginLaunch(void);
void DPLeaveSafeMode(void);
