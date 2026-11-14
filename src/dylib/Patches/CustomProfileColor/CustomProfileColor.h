#import "StdPatch/StdPatch.h"

extern DPPatch DPCustomProfileColor;

// The profile's own color with its alpha, or nil for Dia's.
NSColor *DPCustomColor(NSString *spaceID);
void DPSetCustomColor(NSString *spaceID, NSColor *color);
NSColor *DPDiaProfileColor(NSWindow *window);
NSString *DPCurrentSpaceID(NSWindow *window);
NSString *DPSpaceIDOfItem(NSView *item);
void DPRepaintProfileColors(void);

void DPInstallProfileColorMenu(void);
