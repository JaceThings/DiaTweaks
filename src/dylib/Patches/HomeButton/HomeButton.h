// Home Button: a house after the reload button that opens your home page in the current tab.
#import "StdPatch/StdPatch.h"

extern DPPatch DPHomeButton;
static const CGFloat DPHomeSize = 30, DPHomeGap = 5;  // Dia's toolbar buttons are 30 pt with 5 pt between them.

// Button.m
@interface DPHomeButtonView : NSView
- (void)restyle;  // Takes Dia's colors again, from the buttons beside it.
@end

// HomePage.m
NSString *DPHomePage(void);  // What Settings holds, as typed; empty until one is chosen.
void DPSetHomePage(NSString *page);
NSURL *DPHomeURL(void);      // DPHomePage as a URL, https:// added when there's no scheme; nil when it's empty.
NSString *DPHomeTipText(void);
void DPGoHome(NSWindow *window);

// Tooltip.m: one like Dia's, under `button`, after a short rest. Hidden on exit, click or when the button goes away.
void DPShowHomeTip(NSView *button, NSString *text);
void DPHideHomeTip(void);

// Settings.m
NSArray<NSView *> *DPHomeButtonRows(void);
