#import "StdPatch/StdPatch.h"

// Call once Dia has applied the new title to its existing label.
void DPTidyAnimateTitle(NSTextField *label, NSString *previousTitle);
// Fade out the waiting sweep when the title is ready.
void (^DPTidyShowTitleWaiting(NSView *row))(dispatch_block_t);
// Sweep across the committed title even if its proposal arrived immediately.
void DPTidyPlayTitleSweep(NSView *row);
// Returns NO when the download button is unavailable.
BOOL DPTidyShowDownloadRename(NSView *button, NSString *previousName, NSString *name);
void DPTidyShowTabRename(NSView *tab, NSString *previousName, NSString *name, dispatch_block_t undo);
