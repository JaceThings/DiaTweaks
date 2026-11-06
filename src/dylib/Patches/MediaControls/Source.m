#import "MediaControls.h"

// Chromium's media session states: active, ducking, suspended (paused), inactive.
enum { DPSessionActive = 0, DPSessionDucking = 1, DPSessionSuspended = 2, DPSessionInactive = 3 };
// Chromium's MediaSessionAction numbers.
enum { DPActionPreviousTrack = 2, DPActionNextTrack = 3 };

static char DPAudibleKey, DPSessionKey, DPActionsKey;
char DPMediaMutedKey, DPMediaVolumeKey;
static NSHashTable *DPMediaContents;  // Web contents that have reported any media.
static NSHashTable<NSWindow *> *DPPendingWindows;
static void (^DPChanged)(NSWindow *);

static NSUInteger DPSession(id contents) {
    NSNumber *state = DPGet(contents, &DPSessionKey);
    return state ? state.unsignedIntegerValue : DPSessionInactive;
}

static BOOL DPPlaying(id contents) {
    NSUInteger state = DPSession(contents);
    return state == DPSessionActive || state == DPSessionDucking || [DPGet(contents, &DPAudibleKey) boolValue];
}

// Its media can still be played: playing, or paused with a session to resume.
static BOOL DPHasMedia(id contents) { return DPPlaying(contents) || DPSession(contents) == DPSessionSuspended; }

// Several callbacks arrive together, as a tab starts playing; the card redraws once, after them.
static void DPNoteChange(NSWindow *window) {
    if (!window || !DPChanged) return;
    BOOL scheduled = DPPendingWindows.count > 0;
    [DPPendingWindows addObject:window];
    if (scheduled) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<NSWindow *> *windows = DPPendingWindows.allObjects;
        [DPPendingWindows removeAllObjects];
        for (NSWindow *each in windows) DPChanged(each);
    });
}

void DPMediaRecord(id contents, const void *key, id value) {
    if (!contents) return;
    DPSet(contents, key, value);
    [DPMediaContents addObject:contents];
    DPNoteChange(DPMediaWindowOf(contents));
}

static void DPWC_audible(id self, SEL _cmd, id contents, BOOL audible) {
    DPCallOriginal(DPWC_audible, self, contents, audible);
    DPMediaRecord(contents, &DPAudibleKey, @(audible));
}
static void DPWC_muted(id self, SEL _cmd, id contents, BOOL muted) {
    DPCallOriginal(DPWC_muted, self, contents, muted);
    DPMediaRecord(contents, &DPMediaMutedKey, @(muted));
}
static void DPWC_volume(id self, SEL _cmd, id contents, double volume) {
    DPCallOriginal(DPWC_volume, self, contents, volume);
    if (volume > 0) DPSet(contents, &DPMediaMutedByCardKey, nil);  // The page turned itself back up.
    DPMediaRecord(contents, &DPMediaVolumeKey, @(volume));
}
static void DPWC_session(id self, SEL _cmd, id contents, NSUInteger state) {
    DPCallOriginal(DPWC_session, self, contents, state);
    DPMediaRecord(contents, &DPSessionKey, @(state));
}
static void DPWC_actions(id self, SEL _cmd, id contents, NSIndexSet *actions) {
    DPCallOriginal(DPWC_actions, self, contents, actions);
    DPMediaRecord(contents, &DPActionsKey, [actions copy]);
}

BOOL DPMediaHasMedia(id contents) { return [DPMediaContents containsObject:contents] && DPHasMedia(contents); }
NSArray *DPMediaTabs(void) { return DPMediaContents.allObjects; }

NSArray<DPMediaItem *> *DPMediaItemsInWindow(NSWindow *window) {
    NSMutableArray *items = [NSMutableArray new];
    for (id contents in DPMediaContents.allObjects) {
        if (!DPHasMedia(contents) || DPMediaWindowOf(contents) != window) continue;
        if (DPMediaWaitsForPiP(contents)) continue;
        DPMediaItem *item = [DPMediaItem new];
        NSURL *url = DPMediaGet(contents, @selector(url));
        item.tab = contents;
        item.title = DPMediaText(DPMediaGet(contents, @selector(title))) ?: url.absoluteString ?: @"";
        item.host = [url.host hasPrefix:@"www."] ? [url.host substringFromIndex:4] : url.host ?: @"";
        item.favicon = DPMediaGet(contents, @selector(favicon));
        item.playing = DPPlaying(contents);
        item.muted = DPGet(contents, &DPMediaMutedByCardKey) || [DPGet(contents, &DPMediaMutedKey) boolValue] || [DPGet(contents, &DPMediaVolumeKey) isEqual:@0];
        NSIndexSet *actions = DPGet(contents, &DPActionsKey);
        item.canPrevious = [actions containsIndex:DPActionPreviousTrack];
        item.canNext = [actions containsIndex:DPActionNextTrack];
        [items addObject:item];
    }
    return items;
}

void DPMediaRefresh(id contents) { DPNoteChange(DPMediaWindowOf(contents)); }

void DPInstallMediaSource(void (^changed)(NSWindow *window)) {
    DPMediaContents = [NSHashTable weakObjectsHashTable];
    DPPendingWindows = [NSHashTable weakObjectsHashTable];
    DPChanged = changed;
    DPHook(DPDiaWebContent, @selector(webContents:didChangeAudibleState:), (IMP)DPWC_audible);
    DPHook(DPDiaWebContent, @selector(webContents:didChangeMuteState:), (IMP)DPWC_muted);
    DPHook(DPDiaWebContent, @selector(webContents:didChangeVolume:), (IMP)DPWC_volume);
    DPHook(DPDiaWebContent, @selector(webContents:didChangeMediaSessionState:), (IMP)DPWC_session);
    DPHook(DPDiaWebContent, @selector(webContents:didChangeAvailableMediaActions:), (IMP)DPWC_actions);
}
