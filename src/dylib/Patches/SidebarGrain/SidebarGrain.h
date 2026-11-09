#import "GrainView.h"

extern DPPatch DPSidebarGrain;
extern NSHashTable<NSView *> *DPGrainHosts;

NSInteger DPGrainAmount(void);
NSInteger DPGrainSoftness(void);
NSInteger DPGrainScale(void);
NSMenu *DPGrainTextureMenu(void);
NSArray<NSView *> *DPGrainRows(void);
void DPRefreshSidebarGrain(void);
NSEvent *DPGrainRightClick(NSEvent *event);

BOOL DPGrainHostAvailable(NSView *host);
void DPTrackGrainHost(NSView *host);
NSString *DPVerifyGrainHosts(DPPatch *patch);
