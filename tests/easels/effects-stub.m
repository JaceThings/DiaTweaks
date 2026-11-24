#import <AppKit/AppKit.h>
BOOL DPEaselFixtureDelayDust;
void (^DPEaselFixtureFinishDust)(void);
void DPLibraryDissolve(NSArray<NSView *> *views,void (^completion)(void)) { if(DPEaselFixtureDelayDust) DPEaselFixtureFinishDust=[completion copy]; else completion(); }
