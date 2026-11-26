// The card and the stack at the bottom of the sidebar.
#import "MediaControls.h"

static const CGFloat DPRestHeight = 34, DPExpandedHeight = 76, DPButtonSize = 26, DPSymbolSize = 13.5, DPPeekHeight = 7, DPPeekInset = 9, DPFanGap = 6;
static const CGFloat DPCloseSize = 18;  // The ✕, inside the open card's top right corner.
static const NSTimeInterval DPOpenDuration = 0.22;  // No motion on the card runs past 0.3 s.

extern NSNotificationName const DPMediaStackHeightDidChange;

// Button.m
@interface DPMediaButton : NSButton
- (instancetype)initWithAction:(void (^)(void))action;
- (void)setSymbol:(NSString *)symbol label:(NSString *)label;
- (void)setSymbol:(NSString *)symbol label:(NSString *)label animated:(BOOL)animated;
@property (nonatomic) CGFloat pointSize;     // Of the symbols set after it; DPSymbolSize to begin with.
@property (nonatomic) NSFontWeight weight;
@property (nonatomic, copy) void (^handler)(void);
@property (nonatomic, copy, readonly) NSString *symbol;
- (void)syncHover;  // Checks the pointer again: moving a button sends it no exit, so its hover could stick.
@end

// Motion.m. DPAnimate runs `changes` animated, frames and alpha included, on the curve the card opens and closes
// with. DPFollowAnimation changes plain layers along with it, or at once when no animation is running. DPMorph
// shrinks and blurs a view, calls `swap` to change it, then grows it back sharp unless `swap` says no.
void DPAnimate(void (^changes)(void));
void DPFollowAnimation(void (^changes)(void));
void DPMorph(NSView *view, BOOL (^swap)(void));

// FadeText.m: one line of text that fades out at its end, instead of an ellipsis, when it's too long to fit.
@interface DPFadeText : NSView
- (instancetype)initWithFont:(NSFont *)font color:(NSColor *)color;
@property (nonatomic, copy) NSString *string;
@end

// Card.m: one tab. At rest a row: favicon, title, then play or pause, next and mute. Expanded, it grows upward: the
// title rises over the site, the ✕ shows in the top right corner and previous fades in beside the controls, which stay put.
@interface DPMediaCard : NSView
@property (nonatomic, strong) DPMediaItem *item;
@property (nonatomic) BOOL expanded;
@property (nonatomic) BOOL peeking;  // Tucked behind the front card: only its surface shows.
@property (nonatomic, copy) void (^dismiss)(DPMediaItem *item);
@end

// StackView.m: the newest card in front, the next one peeking out above it; both open up while the pointer is over it.
@interface DPMediaStackView : NSView
@property (nonatomic, strong) DPMediaStack *stack;
- (void)reload;
@property (nonatomic, readonly) CGFloat restHeight;  // What the tab list makes room for; 0 when nothing shows.
@property (nonatomic, readonly) CGFloat height;      // Now: taller than the rest height while open.
@end

// Layout.m: the stack sits just above the sidebar's footer, and the tab list ends above it.
void DPInstallMediaLayout(void);
NSHashTable<NSView *> *DPMediaSidebars(void);
DPMediaStack *DPMediaStackOf(NSWindow *window);
DPMediaStackView *DPMediaStackViewIn(NSView *sidebar);
void DPPlaceMediaStack(NSView *sidebar);
