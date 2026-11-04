// Shared by Peek's files.
#import "StdPatch/StdPatch.h"

extern DPPatch DPPeek;

// The parts of ArcWebContents Peek uses: a page draws in whichever pane host it's attached to.
@protocol DPPeekPage <NSObject>
- (NSView *)createPaneHostView;
- (void)attachToPaneHostView:(NSView *)host;
- (void)detachFromPaneHostView:(NSView *)host;
@end

// A Peek: a card over a window's page area with the page in it, the page behind blurred. Card.m.
@interface DPPeekCard : NSView
@property (nonatomic, strong) NSView *blur, *card, *shade, *clip, *host, *controls;
@property (nonatomic, strong) id<DPPeekPage> page;
@property (nonatomic, weak) id sourceDelegate, source;  // The page it was opened from, and Dia's delegate for that page.
@property (nonatomic, weak) NSView *pane;               // The page area it covers.
@property (nonatomic, strong) id paneObserver, monitor;
@property (nonatomic, strong) NSView *tabBadge;        // Marks the tab the peek came from while it's open. Tab.m.
@property (nonatomic) NSRect link;  // What it grows out of and shrinks back into, in its own coordinates.
@property (nonatomic) CGFloat grown;  // How far it has grown from its card toward filling the page area, as it expands.
@property (nonatomic) BOOL closing;
- (NSRect)cardFrame;
- (void)close:(NSInteger)exit;  // 0 closes, 1 opens it as a tab, 2 in split view: the tags of its buttons.
- (void)handOver;               // Dia showed the page elsewhere: the card lets go of it at once.
@end

@interface DPPeekCard (Motion)  // Motion.m
- (void)animateIn;
- (void)animateOut:(void (^)(void))completion;
- (void)animateExpand:(void (^)(void))completion;
@end

@interface DPPeekCard (Handoff)  // Pages.m
- (void)finish:(NSInteger)exit;
@end

DPPeekCard *DPPeekCardIn(NSWindow *window);
// Card.m. `link` is on screen; `warm` is the host of a page loaded ahead by DPPeekWarm, or nil.
DPPeekCard *DPPeekShowCard(NSWindow *window, id<DPPeekPage> page, NSView *warm, NSRect link);
NSView *DPPeekWarmHost(NSWindow *window, id<DPPeekPage> page);
NSView *DPPeekControls(id target, SEL action);                                      // Controls.m
void DPPeekLayoutHints(NSView *controls, CGFloat availableRight);                    // Controls.m

// Tab.m
void DPPeekShowTabBadge(DPPeekCard *peek, id source, id<DPPeekPage> page);  // Badges the tab the peek came from.
void DPPeekHideTabBadge(DPPeekCard *peek);

// Settings.m
double DPPeekDarkness(void);                  // How dark the page behind a peek is, 0–1, from the settings slider.
double DPPeekResponse(void);                  // The card's spring response in seconds, from the Speed slider; 0.24 like iOS.
double DPPeekBounce(void);                    // How bouncy that spring is, 0–1: 1 minus its damping ratio. 0 like iOS.
BOOL DPPeekGenie(void);                       // Whether the card bends as it opens, from the Genie effect switch.
NSArray<NSView *> *DPPeekSettingsRows(void);  // The Peek settings page's extra rows.

// Pages.m
void DPPeekInstallPages(void);
BOOL DPPeekCanOpen(id source);  // Peek knows which part of Dia made `source`, so can make a page beside it.
void DPPeekOpen(NSWindow *window, NSURL *url, NSPoint origin, id delegate, id source);
void DPPeekWarm(NSWindow *window, id source, NSURL *url);  // Starts loading `url` for a peek that may be about to open.
void DPPeekCool(void);                                     // Drops the page DPPeekWarm loaded, if no peek took it.
BOOL DPPeekShows(id page);
void DPPeekLoad(id page, NSURL *url);
