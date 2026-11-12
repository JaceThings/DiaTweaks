#import "StdPatch/StdPatch.h"
#import "Patches/CommandBar/Tabs.h"

extern DPPatch DPUnloadTab;

void DPWatchFrontTabs(void);
id DPTabBefore(NSWindow *window);
void DPForgetFrontTab(NSWindow *window);  // It's being unloaded, so going back to it would load it again.
