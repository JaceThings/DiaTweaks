// The engine behind DPPatch.hides: Hide.m hides and checks matched views, HideHosts.m finds them where Dia keeps them.
#import "StdPatch/StdPatch.h"

extern NSHashTable<NSView *> *DPHideHosts;  // Views searched again whenever a hide patch toggles.
extern NSHashTable<NSView *> *DPSuppressed;  // Views a patch is hiding that Dia wants shown.
extern const char *const DPHideHostClasses[];

DPPatch *DPHider(NSView *view);     // The patch whose `hides` matches the view, if any.
void DPEnforceHides(NSView *root);  // Hides the matched views under root.
void DPApplyHides(DPPatch *patch);
NSString *DPVerifyHides(DPPatch *patch);
void DPInstallHides(void);
void DPInstallHideHosts(void);
