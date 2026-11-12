#import "Patches/CommandBar/CommandBarOverlay.h"
#import "Patches/CommandBar/Tabs.h"
#import "Patches/CommandBar/HideTab.h"

static char DPSpareKey;

static NSString *const DPSparesKey = @"commandBarSpares";

// Dia brings tabs back after quitting or crashing, so spares and the tabs bars were open over are noted, and closed at the
// next launch while still empty. Never a space's only tab, which would close the window with it.
void DPNoteSpare(NSString *tabID, BOOL parked) {
    NSMutableArray *spares = [[DPSettings() arrayForKey:DPSparesKey] ?: @[] mutableCopy];
    if (tabID) [spares removeObject:tabID];
    if (tabID && parked) [spares addObject:tabID];
    [DPSettings() setObject:spares forKey:DPSparesKey];
}

// last: the final look, after which one still not found, such as one Dia didn't bring back, is forgotten.
void DPCloseLeftSpares(NSArray<NSString *> *left, BOOL last) {
    for (NSString *tabID in left) {
        id tab = nil, space = nil;
        for (NSWindow *window in NSApp.windows) {
            id scriptWindow = DPScriptWindow(window);
            if (tab || ![scriptWindow respondsToSelector:@selector(appleScriptProfiles)]) continue;
            for (id profile in [scriptWindow valueForKey:@"appleScriptProfiles"])
                if (!tab && (tab = DPScriptTabIn(profile, tabID))) space = profile;
        }
        NSString *url = [[tab valueForKey:@"URL"] description];
        if (tab && !url.length && [[space valueForKey:@"appleScriptTabs"] count] > 1) DPCloseTab(tab);
        if (tab || last) DPNoteSpare(tabID, NO);
    }
}

void DPDropSpare(NSWindow *window) {
    DPCommandBarOverlay *spare = DPGet(window, &DPSpareKey);
    if (!spare) return;
    DPSet(window, &DPSpareKey, nil);
    NSString *tabID = DPTabID(spare.openedTab);
    DPNoteSpare(tabID, NO);
    DPWantSpare();
    spare.hidden = NO;
    DPDismiss(spare, YES);
    DPCloseTab(DPScriptTabInAnyProfile(DPScriptWindow(window), tabID));
}

BOOL DPParkSpare(DPCommandBarOverlay *overlay) {
    NSWindow *window = overlay.host;
    NSString *tabID = DPTabID(overlay.openedTab);
    if (!window || !DPSparesOn() || !overlay.returnTab || !DPHidesTab(tabID) || !DPScriptTab(window, tabID) || !DPScriptTab(window, DPTabID(overlay.returnTab)) || DPGet(window, &DPSpareKey) || DPHasStrip(window))
        return NO;
    [overlay.watch invalidate];
    if (overlay.keyMonitor) [NSEvent removeMonitor:overlay.keyMonitor];
    overlay.keyMonitor = nil;
    [overlay.shade removeFromSuperview];
    [overlay.windowBlur removeFromSuperview];
    overlay.shade = overlay.windowBlur = nil;
    overlay.hidden = YES;
    // Emptied now, unless its text is kept, so Dia shrinks the bar back from its results out of sight, not as it shows.
    NSTextView *text = DPBarText(overlay);
    if (!DPCommandBarKeepText.on && text.string.length) [text insertText:@"" replacementRange:NSMakeRange(0, text.string.length)];
    if (DPGet(window, &DPOverlayKey) == overlay) DPSet(window, &DPOverlayKey, nil);
    DPSet(window, &DPSpareKey, overlay);
    DPNoteSpare(tabID, YES);
    DPParkTab(tabID, YES);
    DPStandInFor(window, nil);
    // Back to the page, unless another bar, such as ⌘L's taking over, has the keyboard.
    NSResponder *typing = window.firstResponder;
    if ([typing isKindOfClass:NSView.class] && ![(NSView *)typing isDescendantOf:overlay]) return YES;
    NSView *web = DPFindView(window.contentView, ^BOOL(NSView *view) { return DPIsKind(view, "RenderWidgetHostViewCocoa") && !view.isHiddenOrHasHiddenAncestor; });
    [window makeFirstResponder:web];
    return YES;
}

BOOL DPShowSpare(NSWindow *window) {
    DPCommandBarOverlay *overlay = DPGet(window, &DPSpareKey);
    if (!overlay) return NO;
    NSString *tabID = DPTabID(overlay.openedTab);
    id front = [DPScriptWindow(window) valueForKey:@"activeTab"];
    if ([DPTabID(front) isEqual:tabID]) {
        NSView *page = DPFindView(window.contentView, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaNewTabPage) && !view.isHiddenOrHasHiddenAncestor; });
        DPAdoptSpare(window, page);
        return NO;
    }
    if (!DPSparesOn() || !DPHidesTab(tabID) || !DPScriptTab(window, tabID) || !front || overlay.panel.superview != overlay || DPHasStrip(window)) {
        DPDropSpare(window);
        return NO;
    }
    DPSet(window, &DPSpareKey, nil);  // Still noted: one left blank by quitting with the bar open is closed too.
    DPWantSpare();
    DPFreezeLists(window);  // As they are, with the spare's row left out, so nothing moves.
    DPParkTab(tabID, NO);
    DPSet(window, &DPOverlayKey, overlay);
    overlay.returnTab = front;
    overlay.picked = NO;
    overlay.startURL = [overlay.openedTab valueForKey:@"URL"];
    NSTextView *text = DPBarText(overlay);
    if (DPCommandBarKeepText.on) [text selectAll:nil];
    else [text insertText:@"" replacementRange:NSMakeRange(0, text.string.length)];
    overlay.hidden = NO;
    DPShowShade(overlay);
    overlay.needsLayout = YES;
    DPFocusBar(overlay);
    overlay.keyMonitor = DPWatchKeys(overlay);
    DPStandInFor(window, tabID);
    DPWatch(overlay);
    return YES;
}

DPCommandBarOverlay *DPSpareIn(NSWindow *window) { return DPGet(window, &DPSpareKey); }

// Dia brings a spare forward itself, such as when the tab above it closes or ⌃⇥ reaches it. Once Dia is done, with other
// tabs in the space it closes out of sight, and Dia moves on as if it had never been there. As the space's only tab it
// stays, as an empty tab kept out of the sidebar, since closing it might close the window.
BOOL DPAdoptSpare(NSWindow *window, NSView *page) {
    DPCommandBarOverlay *spare = DPSpareIn(window);
    NSString *tabID = DPTabID(spare.openedTab);
    if (!spare || !page.window || ![DPActiveTabID(window) isEqual:tabID]) return NO;
    DPSet(window, &DPSpareKey, nil);
    DPNoteSpare(tabID, NO);
    spare.hidden = NO;
    DPDismiss(spare, YES);  // Its row stays out of sight meanwhile.
    DPMakeBlank(page, tabID, nil);  // Dia shows it with a page of its own, not the one the bar came from.
    DPWantSpare();
    // The tab that closed can still be listed now, and closing the tab Dia is showing before it's done crashes it.
    __weak NSWindow *weakWindow = window;
    __weak NSView *weakPage = page;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        id scriptWindow = DPScriptWindow(weakWindow), tab = DPScriptTabIn(scriptWindow, tabID);
        if (!tab || [[tab valueForKey:@"URL"] description].length) return;
        if ([[scriptWindow valueForKey:@"appleScriptTabs"] count] < 2) {
            if (weakPage.window) DPMakeBlank(weakPage, tabID, nil);  // Now the only tab, so its row goes too.
            return;
        }
        [DPBlanks(weakWindow) removeObject:tabID];
        DPCloseTab(tab);
    });
    return YES;
}
