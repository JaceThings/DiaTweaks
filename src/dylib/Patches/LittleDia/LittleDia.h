// The window is Dia's popup, the one sites get from window.open. Only Chromium can make one, so a small extension does,
// with chrome.windows.create: the dylib wakes its worker with an omnibox event, the one event Dia lets native code send it.
#import "StdPatch/StdPatch.h"

#define DPDiaOpenURLEvents "_TtC13OpenURLClient19OpenURLEventManager"
#define DPDiaPopupWindow   "_TtC5Popup19PlatformPopupWindow"
#define DPDiaPopupBar      "_TtC5Popup22PopupNavigationBarView"
#define DPDiaPopupTitle    "_TtC13NavigationBar21AssistantBarTitleView"

extern DPPatch DPLittleDia;

void DPInstallLittleDiaExtension(void);
BOOL DPWriteLittleDiaExtension(BOOL on);
NSString *DPLittleDiaExtensionProblem(void);  // nil once its files are written.
BOOL DPSendToLittleDia(NSDictionary *request);  // Hands the extension {action, ...}: see its worker. NO until it's loaded.
BOOL DPLittleDiaStarting(void);  // Dia is launching: it has no window yet or its extensions are still loading.
BOOL DPLittleDiaReady(void);     // DPSendToLittleDia would reach the extension.

NSSize DPLittleDiaSize(void);
NSArray<NSView *> *DPLittleDiaRows(void);

void DPInstallLittleDiaRoute(void);
void DPOpenLinkInLittleDia(NSURL *url);  // A link from Dia's own page, in the current profile.
void DPOpenBlankLittleDia(void);         // A blank page, with its address ready to type.

void DPInstallLittleDiaLinkMenu(void);
NSString *DPLittleDiaLinkMenuProblem(void);

void DPInstallLittleDiaNewWindow(void);
void DPRefreshLittleDiaNewWindow(void);
NSString *DPLittleDiaNewWindowProblem(void);

#define DPLittleDiaWait 3  // Seconds a link waits for its window.
void DPExpectLittleDiaWindow(NSRect frame, NSDictionary *noted, void (^missed)(void), void (^claimed)(NSWindow *window));  // A popup in the next DPLittleDiaWait seconds is this link's, and `claimed` gets it; else `missed` runs. `noted`: what DPNoteStackForLink gave as it arrived.
BOOL DPIsLittleDiaWindow(NSWindow *window);  // Opened by Little Dia, whether or not it's still on.
id DPLittleDiaPage(NSWindow *window);        // Its ArcWebContents, once Chromium has handed it over.
void DPInstallLittleDiaWindows(void);
void DPRefreshLittleDiaWindows(void);
void DPPromoteLittleDiaWindow(NSWindow *window);  // Open in Dia: when it closes, Dia's main window comes forward.

void DPInstallLittleDiaStack(void);
NSDictionary *DPNoteStackForLink(void);  // Where Dia's windows stood and which app the link came from, kept with that link.
void DPRestoreStack(NSWindow *little, NSDictionary *noted);
void DPReturnToSource(pid_t pid);
void DPBringBackPutAway(NSWindow *little);  // Dia's windows put away because it was hidden when the link came.
void DPLinkArrived(void);
BOOL DPHideAgain(void);  // Hides Dia again once its last small window closes, if it was hidden.

void DPInstallLittleDiaBar(void);
// Also Peek's toolbar, so the two bars look and behave alike.
NSButton *DPMakeBarButton(NSString *symbol, NSString *label, NSString *key, void (^action)(void));  // key: with ⌘, or nil.
NSView *DPMakeDivider(void);
void DPMatchPage(NSView *row, id page);  // The row takes the page's color, and a light or dark look to suit it.
void DPRelayoutLittleDiaBars(void);

NSView *DPMakeAddressView(NSView *title);
void DPRefreshAddressView(NSView *view);
void DPEditLittleDiaAddress(NSWindow *window);  // As ⌘L does, once the window has its address.
void DPShowLittleDiaNotice(NSWindow *window, NSString *message);  // In place of the address, for a moment.

void DPInstallLittleDiaShortcuts(void);
NSString *DPLittleDiaShortcutsProblem(void);

NSString *DPLittleDiaURL(NSWindow *window);                   // The page's address, or @"" before it has one.
NSDictionary *DPLittleDiaTab(NSWindow *window, NSString *action);  // A request naming the window's tab.
void DPLittleDiaGo(NSWindow *window, SEL action);             // goBack, goForward or reload
void DPLittleDiaNavigate(NSWindow *window, NSString *typed);  // An address, or words to search for.

NSArray<NSString *> *DPLittleDiaProfiles(void);  // In Dia's order, which DPOpenInProfile's index counts in.
NSImage *DPLittleDiaProfileImage(NSString *name);
void DPOpenInProfile(NSString *url, NSUInteger index, void (^done)(BOOL opened));  // As a focused tab.
