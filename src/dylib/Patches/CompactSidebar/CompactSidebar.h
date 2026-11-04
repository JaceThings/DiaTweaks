// Compact Sidebar: like Zen and Helium, the sidebar shrinks to a strip of icons down the window's left, under a toolbar
// that runs the window's width. Pointing at the strip opens the whole sidebar over the page; ⌘S hides the strip too.
// It's built on Auto-Hide Tabs, which Dia lays the page out for, and which the patch's switch turns on and off.
#import "StdPatch/StdPatch.h"

extern DPPatch DPCompactSidebar;
static const CGFloat DPStripWidth = 64;       // Favorites stack in one column, with room round the selected tab.
static const CGFloat DPLightsClearance = 10;  // Between the window buttons and the toolbar's first button.

// Frames.m: where Auto-Hide Tabs parks the sidebar off the window, it shows as the strip instead. The host is the view
// Dia parks: the sidebar itself, or the floating container once Dia has shown the sidebar in one.
NSView *DPSidebarRootIn(NSWindow *window);
NSView *DPHostIn(NSWindow *window);
NSRect DPDiaHostFrame(NSView *host);     // Where Dia put it.
BOOL DPDiaParked(NSView *host);          // Dia has it parked, as tabs auto-hide.
BOOL DPStripOn(NSView *host);            // On, with Dia's host parked and the strip not hidden with ⌘S.
BOOL DPStripShown(NSWindow *window);
CGFloat DPStripRight(NSWindow *window);  // Where the page starts, from the window's left edge.
void DPPlaceHost(NSView *host);          // Shows it as the strip, open, or where Dia put it.
void DPRefreshWindow(NSWindow *window);  // Places the page and the toolbar's buttons again.
void DPRelayoutCompactSidebar(void);
void DPInstallCompactFrames(void);

// Header.m: the window buttons stay over the toolbar, and only they take clicks there.
CGFloat DPLightsRight(NSWindow *window);  // The window buttons' right edge from the window's left, or 0.
void DPInstallCompactHeader(void);

// Page.m: the page moves right of the strip, the toolbar's buttons right of the window buttons.
void DPRelayoutCompactPanes(NSWindow *window);
void DPClearLightsIn(NSWindow *window);  // Moves the toolbar's buttons right of the window buttons now.
void DPInstallCompactPage(void);

// Rows.m: the sidebar's rows, as icons centered in the strip.
void DPInstallCompactRows(void);

// Chrome.m: the strip, the toolbar and the space around the page share one color, with the page as a card in it.
CGColorRef DPChromeColor(NSWindow *window, NSAppearance *appearance);  // NULL until Dia has made the toolbar.
void DPApplyChrome(NSView *pane);
void DPInstallCompactChrome(void);

// Shortcut.m: ⌘S slides the strip out of the window and back, staying in Auto-Hide Tabs.
BOOL DPStripHiddenIn(NSWindow *window);
BOOL DPStripSliding(NSWindow *window);
BOOL DPStripPresent(NSWindow *window);         // Shown, or sliding in or out.
CGFloat DPStripVisible(NSWindow *window);      // 1 with the strip in place, 0 without, in between while it slides.
CGFloat DPStripSlideDistance(NSWindow *window);  // How far off the window's edge it slides.
void DPMatchAutoHide(BOOL on);                 // Auto-Hide Tabs on with the patch, off without it, in the front window.
void DPInstallCompactShortcut(void);

// Expand.m: the strip's background, and the whole sidebar over the page while the pointer is on the strip.
BOOL DPStripExpanded(NSView *host);
void DPAttachStrip(NSView *host);  // Adds the background and hover tracking once.
void DPLayoutStrip(NSView *host);  // Shows the strip flat, or as a floating card while open.
