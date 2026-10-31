// A small window for links from other apps and quick look-ups, like Arc's Little Arc. It's an ordinary Dia window
// made through Dia's own AppleScript support, so pages share the profile's sign-ins.
#import "StdPatch/StdPatch.h"
#import <Carbon/Carbon.h>

extern DPPatch DPLittleDia;
extern NSHashTable<NSWindow *> *DPLittleWindows;
// There's one Little Dia, kept hidden between uses like Arc's Peek: reusing it skips the 0.7s Dia takes to make a window.
extern __weak NSWindow *DPLittle;
extern BOOL DPLittleOpening;
extern NSUserDefaults *DPLittleDefaults;
extern NSString *const DPLittleWindowIDKey;

// Script.m: Dia's AppleScript, run in process.
NSString *DPQuoted(NSString *text);
NSAppleEventDescriptor *DPDiaScript(NSString *body);
NSString *DPLittleID(NSWindow *window);
void DPSetLittleID(NSWindow *window, NSString *windowID);
void DPMoveToDia(NSWindow *little);
void DPCloseLittleWindows(void);

// Window.m
BOOL DPLittleAlive(NSWindow *window);
NSWindow *DPLittleParent(void);
NSView *DPLittleSidebarHeader(NSWindow *window);
void DPCollapseSidebar(NSWindow *window);
void DPAttachLittle(NSWindow *window, NSWindow *parent);
void DPHideLittle(NSWindow *window);
void DPAddMoveButton(NSWindow *window);  // MoveButton.m

// Open.m
void DPInstallLittleWindowHooks(void);
void DPOpenLittleDia(NSURL *url, BOOL fromPointer, void (^fallback)(void));

// Links.m
void DPInstallLittleLinks(void);
void DPInstallLittleNavigation(void);  // After launch.

CALayer *DPLittleCard(NSRect frame, NSScreen *screen, NSString *label);  // Card.m

// Transition.m: a window-shaped card springs from the link to where Little Dia will be, while Dia builds the real window
// underneath. Core Animation runs it out of process, so it stays smooth while Dia is busy creating the window.
@interface DPLittleTransition : NSObject
- (instancetype)initFrom:(NSPoint)origin scale:(CGFloat)scale to:(NSRect)frame on:(NSScreen *)screen label:(NSString *)label;
- (void)windowReady:(NSWindow *)window id:(NSString *)windowID url:(NSURL *)url;
- (void)cancel;
@end
