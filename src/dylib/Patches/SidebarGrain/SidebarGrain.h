#import "GrainView.h"

extern DPPatch DPSidebarGrain;
extern NSHashTable<NSView *> *DPGrainHosts;

NSInteger DPGrainAmount(void);
NSInteger DPGrainSoftness(void);
void DPRefreshSidebarGrain(void);
NSColor *DPGrainPreviewColor(NSWindow *window, NSAppearance *appearance);
NSArray<NSView *> *DPGrainRowsForWindow(NSWindow *window);
NSEvent *DPGrainRightClick(NSEvent *event);

void DPRefreshGrainRows(void);

BOOL DPGrainHostAvailable(NSView *host);
void DPTrackGrainHost(NSView *host);
NSString *DPVerifyGrainHosts(DPPatch *patch);
