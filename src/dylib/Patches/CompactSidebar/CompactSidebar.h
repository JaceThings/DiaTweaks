// Compact Sidebar: like Zen and Helium, the sidebar shrinks to a strip of icons down the window's left, under a toolbar
// that runs the window's width. Pointing at the strip opens the whole sidebar over the page; ⌘S hides the strip too.
// It's built on Auto-Hide Tabs, which Dia lays the page out for, and which the patch's switch turns on and off.
#import "StdPatch/StdPatch.h"

extern DPPatch DPCompactSidebar, DPCompactSidebarHover;  // Hover.m: whether pointing at the strip opens it.
extern DPPatch DPCompactSidebarHidesToolbar;              // HideToolbarToo.m: whether ⌘S hides the toolbar too.
static const CGFloat DPStripWidth = 64;       // Favorites stack in one column, with room round the selected tab.
static const CGFloat DPLightsClearance = 10;  // Between the window buttons and the toolbar's first button.

// Applies a change at once. The strip's own adjustments to Dia's rows happen as Dia lays them out, often inside one of
// its animations, such as a folder opening, which would otherwise animate them too and slide the icons about.
static inline void DPNow(void (^change)(void)) {
    NSAnimationContext *context = NSAnimationContext.currentContext;
    BOOL implicit = context.allowsImplicitAnimation;
    context.allowsImplicitAnimation = NO;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    change();
    [CATransaction commit];
    context.allowsImplicitAnimation = implicit;
}

// Frames.m: where Auto-Hide Tabs parks the sidebar off the window, it shows as the strip instead. The host is the view
// Dia parks: the sidebar itself, or the floating container once Dia has shown the sidebar in one.
NSView *DPSidebarRootIn(NSWindow *window);
NSView *DPHostIn(NSWindow *window);
NSRect DPDiaHostFrame(NSView *host);     // Where Dia put it.
BOOL DPDiaParked(NSView *host);          // Dia has it parked, as tabs auto-hide, or shows it from the strip.
BOOL DPDiaRevealing(NSView *host);       // Dia shows it from the strip, at the window's edge.
BOOL DPStripOn(NSView *host);            // On, with Dia's host parked and the strip not hidden with ⌘S.
BOOL DPStripShown(NSWindow *window);
CGFloat DPStripRight(NSWindow *window);  // Where the page starts, from the window's left edge.
void DPPlaceHost(NSView *host);          // Shows it as the strip, open, or where Dia put it.
void DPRefreshWindow(NSWindow *window);  // Places the page and the toolbar's buttons again.
void DPRelayoutCompactSidebar(void);
void DPInstallCompactFrames(void);

// Header.m: the window buttons and Dia's downloads button stay over the toolbar, and only they take clicks there.
CGFloat DPLightsRight(NSWindow *window);  // The window buttons' right edge from the window's left, or 0.
CGFloat DPLightsLeft(NSWindow *window);   // And their left edge.
CGFloat DPToolbarAlpha(NSWindow *window);
void DPInstallCompactHeader(void);

// Page.m: the page moves right of the strip, the toolbar's buttons right of the window buttons.
void DPRelayoutCompactPanes(NSWindow *window);
void DPClearLightsIn(NSWindow *window);  // Moves the toolbar's buttons right of the window buttons now.
void DPInstallCompactPage(void);

// Rows.m: the sidebar's rows, as icons centered in the strip.
void DPInstallCompactRows(void);

// Rows.m: how much the footer grows for Chats' row over recent tabs, in the strip.
CGFloat DPChatsRoom(NSWindow *window);

// Folders.m: folders as their icon, with their tabs under them at the strip's width.
void DPInstallCompactFolders(void);

// Chrome.m: the strip, the toolbar and the space around the page share one color, with the page as a card in it.
CGColorRef DPChromeColor(NSWindow *window, NSAppearance *appearance);
CGFloat DPToolbarBottom(NSWindow *window);  // Where the toolbar's bottom edge is once it shows, from the window's bottom.
BOOL DPToolbarHidden(NSWindow *window);     // Hide toolbar keeps it out of sight.
void DPApplyChrome(NSView *pane);
void DPInstallCompactChrome(void);

// Shortcut.m: ⌘S slides the strip out of the window and back, staying in Auto-Hide Tabs, and the toolbar with it if set.
BOOL DPStripHiddenIn(NSWindow *window);
BOOL DPStripSliding(NSWindow *window);
BOOL DPStripPresent(NSWindow *window);         // Shown, or sliding in or out.
CGFloat DPStripVisible(NSWindow *window);      // 1 with the strip in place, 0 without, in between while it slides.
CGFloat DPStripSlideDistance(NSWindow *window);  // How far off the window's edge it slides.
void DPMatchAutoHide(BOOL on);                 // Auto-Hide Tabs on with the patch, off without it, in the front window.
void DPInstallCompactShortcut(void);
void DPMatchStripToolbar(BOOL stripHidden);    // HideToolbarToo.m: hides the toolbar with the strip, or gives it back.

// Reveal.m: with the toolbar hidden, the window buttons show as the pointer reaches the strip's top.
CGFloat DPLightsReveal(NSWindow *window);  // 0 hidden, 1 shown, in between while they fade.
CGFloat DPRevealRoom(NSWindow *window);    // How much wider the strip grows for them.
void DPSettleReveal(NSWindow *window);     // Hides them when the toolbar shows again or the strip goes.
void DPInstallCompactReveal(void);

// List.m: the tabs start under the toolbar, or at the page's top while it's hidden.
NSView *DPListIn(NSWindow *window);
void DPPlaceListIn(NSWindow *window);  // Moves them as the toolbar or the window buttons show.
void DPInstallCompactList(void);

// Downloads.m: Dia's downloads button follows the window buttons over the toolbar, looking like the toolbar's buttons.
NSView *DPDownloadsIn(NSView *root);
CGFloat DPDownloadsMid(NSWindow *window);        // Its icon's middle from the window's left while it shows over the toolbar, or NAN.
CGFloat DPHeaderButtonsRight(NSWindow *window);  // Its right edge while it shows, or the window buttons', or 0.
void DPMatchDownloads(NSWindow *window);         // Fades it with the toolbar, or shows it as Dia does once the sidebar opens.
void DPPlaceDownloadsHover(NSView *bar);         // The toolbar's hover behind it, at the toolbar's buttons' size.
BOOL DPIsDownloadsHover(NSView *view);

// Backdrop.m: the strip blurs with the page while the command bar is open.
void DPInstallCompactBackdrop(void);

// Expand.m: the strip's background, and the whole sidebar over the page while the pointer is on the strip.
BOOL DPStripExpanded(NSView *host);
void DPAttachStrip(NSView *host);  // Adds the background and hover tracking once.
void DPLayoutStrip(NSView *host);  // Shows the strip flat, or as a floating card while open.
