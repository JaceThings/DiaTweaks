#import "StdPatch/StdPatch.h"

extern DPPatch DPDeveloperMode;

typedef NS_ENUM(NSInteger, DPDevPanel) { DPPanelNone, DPPanelInspect, DPPanelConsole, DPPanelNetwork };

// A toolbar button that runs one action in its window. `active` shows it pressed in.
@interface DPDevButton : NSView
@property (nonatomic) DPDevPanel panel;  // The panel it toggles, if any.
@property (nonatomic) BOOL active;
+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label action:(void (^)(NSWindow *window))action;
@end

#define DPDevButtonCount 4
NSArray<DPDevButton *> *DPMakeDevButtons(void);  // DeveloperMode.m

// Panels.m
void DPInstallDevPanels(void);
void DPToggleDevPanel(DPDevPanel panel, NSWindow *window);  // Opens the panel, or closes DevTools if that panel is the one showing.
DPDevPanel DPShownDevPanel(NSWindow *window);

// Sites.m
NSString *DPActiveTabID(NSWindow *window);
NSWindow *DPFrontBrowserWindow(void);
BOOL DPDevModeShown(NSWindow *window);  // Whether the window's page is local, or a site saved with Control-D, and not switched off.
void DPToggleDevMode(NSWindow *window);
void DPWatchDevMode(void);  // The Control-D key, and a timer that notices navigation. Call once Dia has launched.

// Banner.m
NSView *DPMakeDevBanner(NSRect frame);
NSMenu *DPColorChoices(void);  // The Settings menu of banner colors.

// Layout.m
void DPPlaceDevMode(NSView *bar);  // Shows or removes the banner and buttons in a toolbar.
void DPRelayoutDevMode(BOOL onlyChanged);
NSString *DPVerifyDevMode(DPPatch *patch);
