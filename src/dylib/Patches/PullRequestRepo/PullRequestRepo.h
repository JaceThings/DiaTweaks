#import "StdPatch/StdPatch.h"

extern DPPatch DPPullRequestRepo;

BOOL DPIsPRSubtitle(NSView *label);
NSDictionary *DPPullRequestOf(NSView *view);  // @{repo: "hello-world #42 · Open", state, author, tab}, or nil.
void DPRefreshPRSubtitles(void);
void DPInstallPRSubtitles(void);

@interface DPPRStatusLine : NSTextField
@end
void DPSetPRStatus(NSView *subtitle, NSString *tab, NSString *status);
void DPResetPRRows(void);
void DPInstallPRRows(void);
