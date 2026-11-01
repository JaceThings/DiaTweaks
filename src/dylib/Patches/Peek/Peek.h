#import "StdPatch/StdPatch.h"

#define DPPeekWebContent "_TtC3ADK18WebContentChromium"

@interface NSObject (DPPeekNative)
- (id)createWebContents:(id)configuration;
- (NSView *)createPaneHostView;
- (void)attachToPaneHostView:(NSView *)view;
- (void)detachFromPaneHostView:(NSView *)view;
- (id)navigationController;
- (id)load:(NSURL *)url initiatorOrigin:(NSURL *)origin;
- (void)setForeground:(BOOL)value;
- (void)setUntracked:(BOOL)value;
- (void)stop;
- (NSURL *)url;
- (NSView *)nativeView;
- (NSUInteger)navigationType;
@end

@class DPPeekOverlay;
extern DPPatch DPPeek;
BOOL DPPeekCheckABI(void);
void DPPeekInstallTracking(void);
id DPPeekBrowser(id contents);
BOOL DPPeekOpen(id sourceContents, NSURL *url, NSPoint clickInWindow);
void DPPeekCloseContents(id contents);
void DPPeekCloseWindow(NSWindow *window);
void DPPeekCloseAll(void);
NSString *DPPeekVerify(DPPatch *patch);
BOOL DPPeekShouldOpen(NSEvent *event, NSUInteger navigationType, NSInteger policy, NSURL *url);
void DPPeekAnimate(DPPeekOverlay *overlay, BOOL opening, void (^completion)(void));

@interface DPPeekOverlay : NSView
@property(nonatomic) NSPoint origin;
@property(nonatomic, strong) NSView *card;
@property(nonatomic, strong) NSView *host;
@property(nonatomic, strong) NSTextField *heading;
@property(nonatomic, strong) NSButton *closeButton;
@property(nonatomic, copy) void (^dismiss)(void);
@end
