#import "StdPatch/StdPatch.h"

extern DPPatch DPDevMode;

void DPInstallPages(void);
id DPFrontPage(void);
id DPPageIn(NSView *pane);
NSView *DPPaneAbove(NSView *view);
NSView *DPPaneOf(id page);
NSString *DPHostOf(id page);

BOOL DPDevModeOn(NSString *host);  // Local sites are on unless turned off.
void DPSetDevModeOn(NSString *host, BOOL on);
extern NSNotificationName const DPDevModeSitesDidChange;

NSView *DPMakeDevButtons(void);
void DPInstallToolbar(void);
void DPShowStripes(NSView *bar, BOOL shown);
void DPInstallStripes(void);
NSView *DPMakeProfileBackground(void);  // The profile's color over the window's material, as Dia's toasts have.
NSAppearance *DPProfileAppearance(NSWindow *window);
void DPInstallMenuItems(void);
void DPInstallSiteMenu(void);
void DPUpdateMenuItems(void);
NSString *DPVerifyMenuItems(void);
void DPUpdateToolbars(void);
void DPInstallTabOutlines(void);
void DPUpdateTabOutlines(void);
NSString *DPVerifyTabOutlines(void);
NSString *DPVerifyToolbars(DPPatch *patch);

typedef NS_ENUM(NSInteger, DPPortraitBackground) { DPPortraitHue = 1, DPPortraitWallpaper, DPPortraitBlack };
DPPortraitBackground DPPortraitChoice(void);
CGFloat DPPortraitHueValue(void);
void DPSetPortraitStyle(DPPortraitBackground background, CGFloat hue);
NSColor *DPHueColor(CGFloat hue);
void DPFillGradient(CGContextRef context, CGRect rect, NSColor *color);
void DPFillBlack(CGContextRef context, CGRect rect);
BOOL DPFillWallpaper(CGContextRef context, CGRect rect, NSWindow *window);
extern const CGFloat DPPortraitInset, DPPortraitAspect;  // Arc's margin and its wide canvas.
NSImage *DPPortraitImage(NSImage *page, NSWindow *window, CGFloat width, CGFloat aspect);  // width 0: full size; aspect 0: the page's own.

void DPCapturePortrait(id page);
void DPCaptureViewport(id page, void (^done)(NSImage *image));
void DPShowPortraitPopover(NSView *button, id page);
void DPShowCaptureToast(NSView *pane, NSImage *image, NSString *title);
