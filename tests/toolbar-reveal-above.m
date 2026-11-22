#import "Patches/HideToolbar/HideToolbar.h"

DPPatch DPRevealToolbarOnHover, DPShowToolbarWithSidebar, DPShowToolbarOnNewTab, DPShowToolbarWithTopTabs;
BOOL DPBesideSidebar(NSView *view) { return NO; }
BOOL DPLittleDiaIsOver(NSWindow *window) { return NO; }
void DPRepaintTabs(NSWindow *window) {}

@interface _TtC11ContentPane15ContentPaneView : NSView
@end
@implementation _TtC11ContentPane15ContentPaneView
- (BOOL)isFlipped { return YES; }
@end

@interface _TtC13NavigationBar17NavigationBarView : NSView
@end
@implementation _TtC13NavigationBar17NavigationBarView
@end

@interface _TtC11BookmarkBar15BookmarkBarView : NSView
@end
@implementation _TtC11BookmarkBar15BookmarkBarView
@end

// The tracking areas' events, as AppKit sends them.
@interface DPToolbarHover (Events)
- (void)mouseEntered:(NSEvent *)event;
- (void)mouseExited:(NSEvent *)event;
@end

@interface DPKeyWindow : NSWindow
@property BOOL key;
@end
@implementation DPKeyWindow
- (BOOL)isKeyWindow { return self.key; }
@end

static NSPoint pointer;
static NSPoint DPPointer(id self, SEL _cmd) { return pointer; }
static BOOL DPActive(id self, SEL _cmd) { return YES; }

static int failures;
static void Check(BOOL ok, const char *what) {
    if (ok) return;
    failures++;
    fprintf(stderr, "FAIL: %s\n", what);
}

static void DPWait(NSTimeInterval seconds) { CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, false); }

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        DPHookClass(object_getClass(NSEvent.class), @selector(mouseLocation), (IMP)DPPointer);
        DPHookClass(NSApplication.class, @selector(isActive), (IMP)DPActive);
        DPHideToolbar.on = DPRevealToolbarOnHover.on = YES;
        DPHideToolbar.progress = 1;
        DPHideToolbar.install();

        NSScreen *screen = NSScreen.mainScreen;
        NSRect frame = screen ? screen.frame : NSMakeRect(0, 0, 1440, 900);
        // A window just under the menu bar, as a window that fills the screen is.
        DPKeyWindow *window = [[DPKeyWindow alloc] initWithContentRect:NSMakeRect(NSMinX(frame) + 100, NSMaxY(frame) - 330, 400, 300)
                                                             styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
        window.releasedWhenClosed = NO;
        window.key = YES;
        NSView *pane = [[NSClassFromString(@(DPDiaContentPane)) alloc] initWithFrame:window.contentView.bounds];
        NSView *bar = [[NSClassFromString(@(DPDiaToolbar)) alloc] initWithFrame:NSMakeRect(0, 0, 400, 40)];
        [pane addSubview:bar];
        [pane addSubview:[[NSView alloc] initWithFrame:NSMakeRect(0, 40, 400, 260)]];
        [window.contentView addSubview:pane];
        [pane layout];
        DPToolbarHover *hover = [DPToolbarHover forPane:pane];
        Check(hover != nil && !hover.revealed, "the toolbar starts hidden");

        NSRect w = window.frame;
        NSPoint inPage = NSMakePoint(NSMidX(w), NSMidY(w));
        NSPoint overMenuBar = NSMakePoint(NSMidX(w), NSMaxY(w) + 10);
        NSPoint asideAbove = NSMakePoint(NSMaxX(w) + 20, NSMaxY(w) + 10);

        // 2026-11-22: a quick move to the top of the page skipped the 8 pt strip between two moves and
        // ended over the menu bar, outside the window (or over the tabs at the top), and the toolbar
        // never showed.
        pointer = overMenuBar;
        [hover mouseExited:nil];
        Check(hover.revealed, "leaving the window over its top reveals the toolbar");
        DPWait(0.5);
        Check(hover.revealed, "the toolbar stays while the pointer is above the window");

        pointer = inPage;
        DPWait(0.5);
        Check(!hover.revealed, "the toolbar hides once the pointer is back on the page");

        pointer = asideAbove;
        [hover mouseExited:nil];
        Check(!hover.revealed, "above the screen beside the window is not the top of the page");

        window.key = NO;
        pointer = overMenuBar;
        [hover mouseExited:nil];
        Check(!hover.revealed, "a window that isn't key doesn't reveal");
        window.key = YES;

        DPRevealToolbarOnHover.on = NO;
        [hover mouseExited:nil];
        Check(!hover.revealed, "Show Toolbar on Hover off: nothing reveals");
        DPRevealToolbarOnHover.on = YES;

        // The strip itself works as before.
        pointer = [window convertPointToScreen:[pane convertPoint:NSMakePoint(200, 2) toView:nil]];
        [hover mouseEntered:nil];
        Check(hover.revealed, "the strip at the top of the page still reveals");

        // Tabs at the top: the tab strip sits between the page and the top of the window.
        hover.revealed = NO;
        DPWait(0.3);
        [pane removeFromSuperview];
        pane.frame = NSMakeRect(0, 0, 400, 260);
        [window.contentView addSubview:pane];
        [pane layout];
        NSPoint overTabs = NSMakePoint(NSMidX(w), NSMaxY(w) - 20);
        pointer = overTabs;
        [hover mouseExited:nil];
        Check(hover.revealed, "leaving the page into the tabs at the top reveals the toolbar");
        DPWait(0.5);
        Check(hover.revealed, "the toolbar stays while the pointer is over the tabs");
        pointer = overMenuBar;
        DPWait(0.5);
        Check(hover.revealed, "and while it goes on past the window");
        pointer = inPage;
        DPWait(0.5);
        Check(!hover.revealed, "the toolbar hides once the pointer is back on the page below the tabs");

        [window close];
        if (failures) {
            printf("%d toolbar reveal check(s) failed\n", failures);
            return 1;
        }
        puts("all toolbar reveal checks passed");
    }
}
