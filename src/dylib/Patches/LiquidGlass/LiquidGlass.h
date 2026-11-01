#import "StdPatch/StdPatch.h"

extern DPPatch DPLiquidGlass;
@interface DPLiquidSurface : NSView
- (void)refresh;
@end

void DPApplyGlassHost(NSView *host);
void DPInstallGlassHosts(void);
void DPRefreshGlassHosts(void);
NSString *DPVerifyGlassHosts(BOOL enabled);
