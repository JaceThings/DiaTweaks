#import "StdPatch/StdPatch.h"

// Real AppKit views and the real hook chain; stand-ins only for Dia's media objects.
@interface ArcMediaPosition : NSObject
@property double playbackRate;
@property BOOL endOfMedia;
@end
@implementation ArcMediaPosition
@end
@class ArcWebContentsMediaSession;
@interface ArcWebContents : NSObject
@property NSView *nativeView;
@property BOOL audible;
@property ArcWebContentsMediaSession *mediaSession;
@end
@implementation ArcWebContents
@end
@interface ArcWebContentsMediaSession : NSObject
@property (weak) ArcWebContents *owner;
@property ArcMediaPosition *position;
@property id pipController;
@property BOOL acceptsPiP;
@property NSUInteger requests;
- (BOOL)requestPictureInPicture:(NSError **)error;
@end
@implementation ArcWebContentsMediaSession
- (BOOL)requestPictureInPicture:(NSError **)error { self.requests++; return self.acceptsPiP; }
@end
@interface FixtureApplication : NSApplication
@property NSWindow *frontWindow;
@end
@implementation FixtureApplication
- (NSWindow *)mainWindow { return self.frontWindow; }
@end
extern DPPatch DPPictureInPictureOnAppSwitch;
static void leaveApp(void) {
    FixtureApplication *app = (FixtureApplication *)NSApp;
    NSWindow *window = app.frontWindow;
    [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationWillResignActiveNotification object:NSApp];
    app.frontWindow = nil;  // AppKit is allowed to clear mainWindow while inactive.
    [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationDidResignActiveNotification object:NSApp];
    app.frontWindow = window;
}
int main(void) {
    __weak ArcWebContentsMediaSession *weakSession;
    @autoreleasepool {
    FixtureApplication *app = [FixtureApplication sharedApplication];
    app.frontWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
                                                styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    NSView *page = [[NSView alloc] initWithFrame:app.frontWindow.contentView.bounds];
    [app.frontWindow.contentView addSubview:page];
    ArcWebContents *contents = [ArcWebContents new]; contents.nativeView = page;
    ArcWebContentsMediaSession *session = [ArcWebContentsMediaSession new];
    session.owner = contents; session.acceptsPiP = YES; session.position = [ArcMediaPosition new];
    contents.mediaSession = session;
    DPPictureInPictureOnAppSwitch.install();
    NSCAssert(contents.mediaSession == session, @"getter must still return Dia's session");
    for (int layout = 0; layout < 2; layout++) {
        // Different page geometry must not affect the native media path.
        page.frame = layout ? NSMakeRect(0, 0, 800, 550) : NSMakeRect(200, 0, 600, 600);
        session.requests = 0; session.position.playbackRate = 1;
        DPPictureInPictureOnAppSwitch.on = NO; leaveApp();
        NSCAssert(session.requests == 0, @"disabled patch must do nothing");
        DPPictureInPictureOnAppSwitch.on = YES; leaveApp();
        NSCAssert(session.requests == 1, @"playing video enters PiP on app deactivation");
        session.requests = 0; session.position.playbackRate = 0; leaveApp();
        NSCAssert(session.requests == 0, @"paused media must stay put");
        session.position.playbackRate = 1; session.position.endOfMedia = YES; leaveApp();
        NSCAssert(session.requests == 0, @"ended media must stay put");
        session.position.endOfMedia = NO; page.hidden = YES; leaveApp();
        NSCAssert(session.requests == 0, @"background tabs must stay put");
        page.hidden = NO; session.pipController = [NSObject new]; leaveApp();
        NSCAssert(session.requests == 0, @"manual PiP must not be replaced");
        session.pipController = nil;
        NSWindow *front = app.frontWindow; app.frontWindow = nil; leaveApp(); app.frontWindow = front;
        NSCAssert(session.requests == 0, @"no browser window must do nothing");
        session.position = nil; contents.audible = NO; leaveApp();
        NSCAssert(session.requests == 0, @"silent media without a timeline cannot prove playback");
        contents.audible = YES; leaveApp();
        NSCAssert(session.requests == 1, @"audible live stream can request PiP");
        session.position = [ArcMediaPosition new]; contents.audible = NO;
    }
    weakSession = session;
    }
    NSCAssert(weakSession == nil, @"tracking must not retain a closed tab's media session");
    puts("ok: PiP app notifications, toggle, playback, hidden tabs, manual PiP and both page geometries");
}
