#import "MediaControls.h"

static BOOL DPRun(id session, SEL action) {
    if (![session respondsToSelector:action]) return NO;
    NSError *error = nil;
    BOOL ok = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(session, action, &error);
    if (!ok) NSLog(@"DiaPatches: media %@ failed: %@", NSStringFromSelector(action), error);
    return ok;
}

static char DPVolumeBeforeMuteKey;
char DPMediaMutedByCardKey;

// The media session mutes the page's player; with several players it refuses, so the volume goes to zero instead.
// The card remembers that it muted the tab, because the session doesn't always report it back; unmuting undoes both
// ways, so whichever took hold is released.
static void DPToggleMute(id contents, id session) {
    BOOL (*setMute)(id, SEL, BOOL, NSError **) = (void *)objc_msgSend;
    BOOL (*setVolume)(id, SEL, double, NSError **) = (void *)objc_msgSend;
    if (![session respondsToSelector:@selector(setMute:error:)] || ![session respondsToSelector:@selector(setVolume:error:)]) return;
    NSNumber *volume = DPGet(contents, &DPMediaVolumeKey);
    BOOL muted = DPGet(contents, &DPMediaMutedByCardKey) || [DPGet(contents, &DPMediaMutedKey) boolValue] || [volume isEqual:@0];
    if (muted) {
        setMute(session, @selector(setMute:error:), NO, NULL);
        NSNumber *before = DPGet(contents, &DPVolumeBeforeMuteKey);
        if (before || [volume isEqual:@0]) setVolume(session, @selector(setVolume:error:), before.doubleValue > 0 ? before.doubleValue : 1, NULL);
        DPSet(contents, &DPVolumeBeforeMuteKey, nil);
        DPSet(contents, &DPMediaMutedByCardKey, nil);
    } else {
        if (!setMute(session, @selector(setMute:error:), YES, NULL)) {
            DPSet(contents, &DPVolumeBeforeMuteKey, volume ?: @1);
            setVolume(session, @selector(setVolume:error:), 0, NULL);
        }
        DPSet(contents, &DPMediaMutedByCardKey, @YES);
    }
    DPMediaRefresh(contents);
}

// The tab as Dia's AppleScript support sees it, which can bring it forward: the same window, then the same address,
// then the same title if several tabs share the address.
static id DPScriptingTab(id contents) {
    NSString *windowID = DPMediaGet(DPMediaBrowserOf(contents), @selector(windowIdentifier));
    NSString *url = [DPMediaGet(contents, @selector(url)) absoluteString], *title = DPMediaText(DPMediaGet(contents, @selector(title)));
    id match = nil;
    for (id window in [NSApp valueForKey:@"appleScriptWindows"]) {
        if (windowID && ![[window valueForKey:@"windowId"] isEqual:windowID]) continue;
        for (id tab in [window valueForKey:@"appleScriptTabs"]) {
            if (![[tab valueForKey:@"URL"] isEqual:url]) continue;
            if (!match || [[tab valueForKey:@"title"] isEqual:title]) match = tab;
        }
    }
    return match;
}

void DPMediaPerform(DPMediaItem *item, DPMediaAction action) {
    id contents = item.tab;
    id session = [contents respondsToSelector:@selector(mediaSession)] ? DPMediaGet(contents, @selector(mediaSession)) : nil;
    switch (action) {
    case DPMediaPlayPause: DPRun(session, item.playing ? @selector(pause:) : @selector(play:)); break;
    case DPMediaPrevious: DPRun(session, @selector(playPreviousTrack:)); break;
    case DPMediaNext: DPRun(session, @selector(playNextTrack:)); break;
    case DPMediaToggleMute: DPToggleMute(contents, session); break;
    case DPMediaSelect: {
        id tab = DPScriptingTab(contents);
        if ([tab respondsToSelector:@selector(focus:)]) ((void (*)(id, SEL, id))objc_msgSend)(tab, @selector(focus:), nil);
        else NSBeep();
        break;
    }
    }
}
