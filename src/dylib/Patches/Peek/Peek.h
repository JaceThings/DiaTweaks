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
@property (nonatomic, strong) NSView *blur, *card, *clip, *host, *controls;
@property (nonatomic, strong) id<DPPeekPage> page;
@property (nonatomic, weak) id sourceDelegate, source;  // The page it was opened from, and Dia's delegate for that page.
@property (nonatomic, weak) NSView *pane;               // The page area it covers.
@property (nonatomic, strong) id paneObserver, monitor;
@property (nonatomic) NSRect link;  // What it grows out of and shrinks back into, in its own coordinates.
@property (nonatomic) BOOL closing;
- (NSRect)cardFrame;
- (void)close:(NSInteger)exit;  // 0 closes, 1 opens it as a tab, 2 in split view: the tags of its buttons.
- (void)handOver;               // Dia showed the page elsewhere: the card lets go of it at once.
@end

@interface DPPeekCard (Motion)  // Motion.m
- (void)animateIn;
- (void)animateOut:(void (^)(void))completion;
@end

@interface DPPeekCard (Handoff)  // Pages.m
- (void)finish:(NSInteger)exit;
@end

DPPeekCard *DPPeekCardIn(NSWindow *window);
DPPeekCard *DPPeekShowCard(NSWindow *window, id<DPPeekPage> page, NSPoint origin);  // Card.m
NSView *DPPeekControls(id target, SEL action);                                      // Controls.m

// Pages.m
void DPPeekInstallPages(void);
BOOL DPPeekCanOpen(id source);  // Peek knows which part of Dia made `source`, so can make a page beside it.
void DPPeekOpen(NSWindow *window, NSURL *url, NSPoint origin, id delegate, id source);
BOOL DPPeekShows(id page);
void DPPeekLoad(id page, NSURL *url);
