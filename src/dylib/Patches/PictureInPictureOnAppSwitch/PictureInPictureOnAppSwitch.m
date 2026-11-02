#import "StdPatch/StdPatch.h"

// ArcCore owns the player and PiP window. Keep weak references so closed tabs are never kept alive.
@protocol DPPiPPosition <NSObject>
- (double)playbackRate;
- (BOOL)endOfMedia;
@end
@protocol DPPiPContents <NSObject>
- (NSView *)nativeView;
- (BOOL)audible;
@end
@protocol DPPiPSession <NSObject>
- (id<DPPiPContents>)owner;
- (id<DPPiPPosition>)position;
- (id)pipController;
- (BOOL)requestPictureInPicture:(NSError **)error;
@end

extern DPPatch DPPictureInPictureOnAppSwitch;
static NSHashTable<id<DPPiPSession>> *DPSessions;
static __weak NSWindow *DPDepartingWindow;

static id DPContents_mediaSession(id self, SEL _cmd) {
    id session = DPCallOriginal(DPContents_mediaSession, self);
    if (session) [DPSessions addObject:session];
    return session;
}

static BOOL DPPlaying(id<DPPiPSession> session) {
    id<DPPiPPosition> position = session.position;
    // Live streams may not publish a timeline. Muted video with a timeline still counts as playing.
    if (!position) return session.owner.audible;
    return [position respondsToSelector:@selector(playbackRate)] && [position respondsToSelector:@selector(endOfMedia)]
        && position.playbackRate > 0 && !position.endOfMedia;
}

static void DPLeaveApp(void) {
    NSWindow *window = DPDepartingWindow;
    DPDepartingWindow = nil;
    if (!DPPictureInPictureOnAppSwitch.on) return;
    NSArray<id<DPPiPSession>> *sessions = DPSessions.allObjects;
    // Do not replace PiP opened by the user, another tab, or Dia's existing tab-switch behavior.
    for (id<DPPiPSession> session in sessions) if (session.pipController) return;
    if (!window || window.miniaturized || [window isKindOfClass:NSPanel.class]) return;
    for (id<DPPiPSession> session in sessions) {
        NSView *view = session.owner.nativeView;
        if (!view || view.window != window || view.hiddenOrHasHiddenAncestor || !DPPlaying(session)) continue;
        // ArcCore checks whether this media has a video eligible for PiP; audio-only sessions cannot enter it.
        if ([session requestPictureInPicture:NULL]) break;
    }
}

static void DPInstallPictureInPictureOnAppSwitch(void) {
    Class cls = objc_getClass(DPDiaMediaSession);
    for (NSString *name in @[ @"owner", @"position", @"pipController", @"requestPictureInPicture:" ]) {
        if (class_getInstanceMethod(cls, NSSelectorFromString(name))) continue;
        DPPictureInPictureOnAppSwitch.unavailable = YES;
        DPPictureInPictureOnAppSwitch.on = NO;
        return;
    }
    if (!class_getInstanceMethod(objc_getClass(DPDiaWebContents), @selector(mediaSession))) {
        DPPictureInPictureOnAppSwitch.unavailable = YES;
        DPPictureInPictureOnAppSwitch.on = NO;
        return;
    }
    DPSessions = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaWebContents, @selector(mediaSession), (IMP)DPContents_mediaSession);
    // mainWindow can become nil once the app is inactive. Capture it before deactivation finishes.
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue
                                               usingBlock:^(NSNotification *_) { DPDepartingWindow = NSApp.mainWindow; }];
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification object:nil queue:NSOperationQueue.mainQueue
                                               usingBlock:^(NSNotification *_) { DPLeaveApp(); }];
}

DP_PATCH(DPPictureInPictureOnAppSwitch) {
    .key = @"pictureInPictureOnAppSwitch",
    .order = 91,
    .title = @"Picture in picture on app switch",
    .detail = @"Open picture in picture for playing video in the front window when you switch to another app. Uses Dia's player and leaves an existing picture-in-picture window alone. Experimental.",
    .symbol = @"pip.enter",
    .tint = @"systemIndigoColor",
    .section = @"Window",
    .classes = DPClasses(DPDiaMediaSession, DPDiaWebContents),
    .install = DPInstallPictureInPictureOnAppSwitch,
};
