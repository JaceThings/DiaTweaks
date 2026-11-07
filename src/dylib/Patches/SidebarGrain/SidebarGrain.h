#import "GrainView.h"

extern DPPatch DPSidebarGrain;
extern NSHashTable<NSView *> *DPGrainSidebars;

NSInteger DPGrainAmount(void);
NSInteger DPGrainSoftness(void);
void DPRefreshSidebarGrain(void);
NSColor *DPGrainPreviewColor(NSWindow *window, NSAppearance *appearance);
NSArray<NSView *> *DPGrainRowsForWindow(NSWindow *window);
NSEvent *DPGrainRightClick(NSEvent *event);

void DPRefreshGrainRows(void);
