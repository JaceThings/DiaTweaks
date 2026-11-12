#import <Foundation/Foundation.h>

// The catalog lives outside the bundle so `DPSwitchIcon` can change the icon without touching the signature. Returns what
// happened, for the log; a problem leaves Dia's own catalog in place and never stops a build. `installed` is the Dia in use,
// whose catalog must survive.
NSString *DPPrepareIcons(NSString *app, NSString *installed, NSString *home);

// nil on success, else what went wrong.
NSString *DPSwitchIcon(NSString *app, NSString *home);
