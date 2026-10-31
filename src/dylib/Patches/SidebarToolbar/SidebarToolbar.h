// The toolbar docked at the top of the sidebar, as in Arc.
#import "StdPatch/StdPatch.h"

extern DPPatch DPSidebarToolbar;
extern NSHashTable<NSView *> *DPSidebars, *DPDockPanes, *DPDockBars;
static const CGFloat DPDockInset = 6, DPDockRowHeight = 32, DPDockFieldHeight = 34, DPDockBottom = 10;

// Dock.m: which bar goes in which sidebar.
BOOL DPDocking(void);  // On, and the hidden toolbar isn't taking its place.
BOOL DPIsDocked(NSView *bar);
NSView *DPToolbarOf(NSView *view);  // The toolbar the view is in, if any.
BOOL DPSidebarShown(NSView *sidebar);  // In its window, not hidden, and the page isn't over it.
NSView *DPShownSidebar(NSWindow *window);
NSView *DPPaneBar(NSView *pane);
void DPUndockAll(NSView *sidebar);
void DPUpdateDock(NSWindow *window);
void DPUpdateDocks(void);
void DPScheduleDocks(void);
void DPInstallDock(void);

// Pane.m: the page moves up into the docked bar's place.
void DPRestorePane(NSView *pane);
void DPInstallPane(void);

// Toolbar.m
NSRect DPPaneFrame(NSView *bar);  // The frame Dia gave the bar in its pane, wherever the bar is.
void DPSetBarFrame(NSView *bar, NSRect frame);
void DPApplyBarAppearance(NSView *bar);
void DPInstallToolbar(void);

// Sidebar.m: room for the bar under the sidebar's header.
NSView *DPSidebarHeader(NSView *sidebar);
NSRect DPHeaderRow(NSView *sidebar);  // The row of the header's controls, in the sidebar's coordinates.
NSView *DPLights(NSView *header);
CGFloat DPHeaderGap(NSView *sidebar);
NSRect DPDockFrame(NSView *sidebar, NSView *bar);
void DPSetHiddenByUs(NSView *view, BOOL hidden);
void DPInstallSidebar(void);

// Footer.m
void DPArrangeFooter(NSView *sidebar, NSView *header, BOOL docked);
NSStackView *DPDownloadsHome(NSView *downloads);
void DPForgetDownloadsHome(NSView *downloads);

// Bar.m and Place.m: the bar's controls, docked or back as Dia had them.
NSView *DPBarAddress(NSView *bar);
NSTextView *DPBarText(NSView *bar);
NSView *DPAddressField(NSView *bar);
BOOL DPIsSidebarToggle(NSView *item);
NSArray<NSView *> *DPBarItems(NSView *bar, BOOL navigation);  // Navigation buttons, or everything else beside the address.
BOOL DPIsFaded(NSView *item);
void DPFadeUnlessFits(NSView *item, BOOL fits);
void DPArrangeBar(NSView *bar);
void DPPlaceDocked(NSView *bar, NSView *row, NSView *field);

// Extensions.m
void DPArrangeExtensions(NSView *bar, NSView *row, BOOL docked);
NSView *DPExtensionsButton(NSView *bar);  // nil unless docked with extensions to show.
void DPInstallExtensions(void);

// Address.m and Theme.m
void DPArrangeAddress(NSView *address, BOOL docked);
void DPTheme(id object, SEL setter);
void DPThemeIcons(NSView *view);
void DPInstallAddress(void);

// SplitAddress.m: in a split view each pane keeps its bar, and the sidebar shows the focused one's address.
@interface DPFieldView : NSView
@end
@interface DPSplitAddress : NSView
@property (weak) NSView *bar;
- (void)update;
@end
void DPShowSplitAddress(NSWindow *window, NSView *sidebar, NSView *bar);
void DPOpenCommandBar(void);
void DPInstallSplitAddress(void);

// Popovers.m
void DPInstallPopovers(void);
