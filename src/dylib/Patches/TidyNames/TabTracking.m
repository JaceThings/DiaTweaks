#import "Feedback.h"
#import "Names.h"
#import "Commands/GroupTabs/GroupTabs.h"

extern DPPatch DPTidyNames, DPTidyTabTitles;
NSString *DPTidyTabIdentifier(id model);
NSDictionary<NSString *, NSString *> *DPTidyTabLocations(id outline);
NSArray<NSString *> *DPTidyNewlyPinnedTabs(NSDictionary *previous, NSDictionary *current);
int32_t DPTidyTabTitleStatus(id model);
enum { DPTidyTitlePending, DPTidyTitleProtected, DPTidyTitleEditable };
BOOL DPTidyRenameTabRow(NSView *row, NSString *previous, NSString *name, void (^finished)(BOOL saved));
NSTextField *DPTidyTabContentTitle(NSView *row);
void DPInstallTidyRenameDialog(void);

static char DPTidyListStateKey;
static const char *const DPTidyStrip = "_TtC8TabStrip21TabStripContainerView";
static const char *const DPTidyCollection = "_TtCC7TabList11TabListView14CollectionView";
static const char *const DPTidyDock = "_TtC10TabSurface11TabDockView";
@interface DPTidyTitleProposal : NSObject
@property(copy) NSString *title, *url, *name;
@property NSUInteger attempts;
@end
@implementation DPTidyTitleProposal @end

@interface DPTidyListState : NSObject
@property NSDictionary<NSString *, NSString *> *locations;
@property NSDictionary<NSString *, NSString *> *plainTitles;
@property(copy) NSString *draggedIdentifier, *draggedTitle;
@property NSTimeInterval draggedAt;
@property NSMutableDictionary<NSString *, NSString *> *pending;
@property NSMutableDictionary<NSString *, NSNumber *> *deadlines;
@property NSMutableSet<NSString *> *waitingForRow;
@property NSMutableDictionary<NSString *, NSString *> *favoriteTitles;
@property NSMutableDictionary<NSString *, DPTidyTitleProposal *> *proposals;
@property(weak) NSWindow *window;
@property BOOL scheduled, retryScheduled, processing, dragging;
@end
@implementation DPTidyListState @end

static BOOL DPTidyTitlesEnabled(void) {
    return DPTidyNames.on && DPTidyTabTitles.on;
}

static NSDictionary *DPTidyOutline(NSView *list) {
    NSDictionary *locations = DPTidyTabLocations(list);
    if (!locations || !DPIsKind(list, DPTidyStrip)) return locations;
    NSMutableDictionary *result = locations.mutableCopy;
    DPFindView(list.window.contentView, ^BOOL(NSView *view) {
        if (DPIsKind(view, DPDiaPinnedTab) && !view.hiddenOrHasHiddenAncestor) {
            NSString *identifier = DPTidyTabIdentifier(view);
            if (identifier.length) result[identifier] = @"favorites";
        }
        return NO;
    });
    return result;
}

static void DPTidyScheduleScan(NSView *surface);

static id DPTidyScriptTab(NSWindow *window, NSString *identifier) {
    for (id scripted in DPMsg(NSApp.delegate, @selector(appleScriptWindows))) {
        if (![DPMsg(scripted, @selector(windowId)) isEqual:window.identifier]) continue;
        for (id tab in DPMsg(scripted, @selector(appleScriptTabs))) {
            NSString *tabID = DPText(DPMsg(tab, @selector(tabId)));
            if (tabID.length && [tabID caseInsensitiveCompare:identifier] == NSOrderedSame) return tab;
        }
    }
    return nil;
}

static NSView *DPTidyTabRow(NSView *list, NSString *identifier, BOOL favorite) {
    const char *className = favorite ? DPDiaPinnedTab : DPDiaTabView;
    return DPFindView(favorite ? list.window.contentView : list, ^BOOL(NSView *view) {
        return DPIsKind(view, className) && !view.hiddenOrHasHiddenAncestor &&
            [DPTidyTabIdentifier(view) isEqualToString:identifier];
    });
}

static int32_t DPTidyRowTitleStatus(NSView *row) {
    NSView *content = DPFindView(row, ^BOOL(NSView *view) {
        return [NSStringFromClass(view.class) isEqualToString:@"TabUI.TabContentView"];
    });
    return content ? DPTidyTabTitleStatus(content) : DPTidyTitlePending;
}

static NSString *DPTidyPlainTitle(NSView *row) {
    NSString *title = DPTidyTabContentTitle(row).stringValue;
    return title.length && DPTidyRowTitleStatus(row) == DPTidyTitleEditable ? title : nil;
}

static NSDictionary *DPTidyPlainTitles(NSView *list) {
    NSMutableDictionary *titles = [NSMutableDictionary new];
    DPFindView(list, ^BOOL(NSView *view) {
        if (!DPIsKind(view, DPDiaTabView) || view.hiddenOrHasHiddenAncestor) return NO;
        NSString *title = DPTidyPlainTitle(view);
        if (!title) return NO;
        NSString *identifier = DPTidyTabIdentifier(view);
        if (identifier.length) titles[identifier] = title;
        return NO;
    });
    return titles;
}

static void DPTidyForgetTitle(DPTidyListState *state, NSString *identifier) {
    [state.pending removeObjectForKey:identifier];
    [state.deadlines removeObjectForKey:identifier];
    [state.waitingForRow removeObject:identifier];
    [state.favoriteTitles removeObjectForKey:identifier];
    [state.proposals removeObjectForKey:identifier];
}

static void DPTidyRequestTabTitle(NSView *list, NSView *row, DPTidyListState *state, NSString *identifier, NSString *location) {
    BOOL favorite = [location isEqualToString:@"favorites"];
    NSString *favoriteTitle = state.favoriteTitles[identifier];
    if (!list.window.isKeyWindow || [list.window.firstResponder isKindOfClass:NSTextView.class]) return;
    id tab = DPTidyScriptTab(list.window, identifier);
    if (!tab || DPMsgBool(tab, @selector(loading))) return;
    int32_t titleStatus = favorite ? DPTidyTitleEditable : DPTidyRowTitleStatus(row);
    if (titleStatus == DPTidyTitlePending) return;
    NSString *title = DPText(DPMsg(tab, @selector(title)));
    NSString *url = DPText(DPMsg(tab, @selector(URL)));
    NSURL *pageURL = url.length ? [NSURL URLWithString:url] : nil;
    NSString *source = DPTidyNameSource(pageURL);
    NSString *sectionTitle = source.length ? DPTidySectionTitle(title, pageURL) : nil;
    if ((favorite ? ![favoriteTitle isEqualToString:title] : titleStatus != DPTidyTitleEditable) ||
        !source.length || (!sectionTitle && !DPTidyTitleNeedsRename(title))) return DPTidyForgetTitle(state, identifier);

    state.processing = YES;
    __weak NSView *weakList = list;
    dispatch_block_t finished = ^{
        state.processing = NO;
        if (DPGet(weakList, &DPTidyListStateKey) == state) DPTidyScheduleScan(weakList);
    };
    DPTidyTitleProposal *existing = state.proposals[identifier];
    if (existing) {
        if ([existing.title isEqualToString:title] && [existing.url isEqualToString:url] &&
            DPTidyRenameTabRow(row, title, existing.name, ^(BOOL saved) {
                if (state.proposals[identifier] == existing && (saved || existing.attempts >= 2))
                    DPTidyForgetTitle(state, identifier);
                finished();
            })) {
            existing.attempts++;
            return;
        }
        if (![existing.title isEqualToString:title] || ![existing.url isEqualToString:url])
            DPTidyForgetTitle(state, identifier);
        state.processing = NO;
        return;
    }
    void (^stopWaiting)(dispatch_block_t) = DPTidyShowTitleWaiting(row);
    NSNumber *deadline = state.deadlines[identifier];
    __block BOOL settled = NO;
    void (^accept)(NSString *) = ^(NSString *candidate) {
        if (settled) return;
        settled = YES;
        stopWaiting(^{
            NSView *currentList = weakList;
            if (!DPTidyTitlesEnabled() || !currentList.window || state.deadlines[identifier] != deadline ||
                NSProcessInfo.processInfo.systemUptime >= deadline.doubleValue) return finished();
            NSString *name = DPTidyValidatedTitle(candidate, title) ?: DPTidyFallbackTitle(title);
            if (name) {
                DPTidyTitleProposal *proposal = [DPTidyTitleProposal new];
                proposal.title = title;
                proposal.url = url;
                proposal.name = name;
                state.proposals[identifier] = proposal;
            } else DPTidyForgetTitle(state, identifier);
            finished();
        });
    };
    if (sectionTitle) {
        DPTidyTitleProposal *proposal = [DPTidyTitleProposal new];
        proposal.title = title;
        proposal.url = url;
        proposal.name = sectionTitle;
        state.proposals[identifier] = proposal;
        stopWaiting(finished);
        return;
    }
    DPTidyProposeName(@"tab", title, source, @"", @"", accept);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1800 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ accept(nil); });
}

static void DPTidyScanList(NSView *list, DPTidyListState *state) {
    // Dia temporarily moves rows while showing a drop target. Compare the
    // settled outline after AppKit reports the end of the native session.
    if (!DPTidyTitlesEnabled() || !list.window || state.dragging) return;
    NSDictionary<NSString *, NSString *> *latest = DPTidyOutline(list);
    if (!latest) return;
    if (!state.locations || state.window != list.window) {
        state.window = list.window;
        state.locations = latest;
        state.plainTitles = DPTidyPlainTitles(list);
        state.draggedIdentifier = nil;
        state.draggedTitle = nil;
        [state.pending removeAllObjects];
        [state.deadlines removeAllObjects];
        [state.waitingForRow removeAllObjects];
        [state.favoriteTitles removeAllObjects];
        [state.proposals removeAllObjects];
        return;
    }
    // The source row can disappear in an intermediate layout before the dock inserts its tile.
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    BOOL dragIsRecent = now - state.draggedAt < 10;
    BOOL outlineChanged = ![state.locations isEqualToDictionary:latest];
    if (outlineChanged) {
        NSArray<NSString *> *newlyPinned = DPTidyNewlyPinnedTabs(state.locations, latest);
        // Names are generated and saved one at a time. Give the queue enough
        // time for its last member to reach the front even on a slow model.
        NSTimeInterval batchDeadline = now + 6 + 3 * (state.pending.count + newlyPinned.count);
        for (NSString *identifier in newlyPinned) {
            NSString *location = latest[identifier];
            NSString *original = state.plainTitles[identifier];
            if (dragIsRecent && [identifier isEqualToString:state.draggedIdentifier] &&
                [location isEqualToString:@"favorites"]) {
                original = state.draggedTitle;
                state.draggedIdentifier = nil;
                state.draggedTitle = nil;
            }
            if ([location isEqualToString:@"favorites"] && !original) continue;
            state.favoriteTitles[identifier] = original;
            state.pending[identifier] = location;
            state.deadlines[identifier] = @(batchDeadline);
            [state.proposals removeObjectForKey:identifier];
        }
        state.locations = latest;
        state.plainTitles = DPTidyPlainTitles(list);
    }
    BOOL retryVisible = NO;
    for (NSString *identifier in [state.pending.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *location = state.pending[identifier];
        if (![latest[identifier] isEqualToString:location]) {
            DPTidyForgetTitle(state, identifier);
            continue;
        }
        if (state.processing) continue;
        NSView *row = DPTidyTabRow(list, identifier, [location isEqualToString:@"favorites"]);
        if (!row) {
            // A collapsed group or scrolled-out row has no native rename
            // action to invoke. Its next layout will resume the request.
            [state.waitingForRow addObject:identifier];
            continue;
        }
        if ([state.waitingForRow containsObject:identifier]) {
            [state.waitingForRow removeObject:identifier];
            state.deadlines[identifier] = @(now + 6 + 3 * state.pending.count);
        }
        if (now >= state.deadlines[identifier].doubleValue) {
            DPTidyForgetTitle(state, identifier);
            continue;
        }
        retryVisible = YES;
        DPTidyRequestTabTitle(list, row, state, identifier, location);
    }
    if (retryVisible && state.pending.count && !state.processing && !state.retryScheduled) {
        state.retryScheduled = YES;
        __weak NSView *weakList = list;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 160 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            state.retryScheduled = NO;
            if (DPGet(weakList, &DPTidyListStateKey) == state) DPTidyScheduleScan(weakList);
        });
    }
}

static void DPTidyScheduleScan(NSView *surface) {
    DPTidyListState *state = DPGet(surface, &DPTidyListStateKey);
    if (!DPTidyTitlesEnabled()) {
        if (state) DPSet(surface, &DPTidyListStateKey, nil);
        return;
    }
    if (!state) {
        state = [DPTidyListState new];
        state.pending = [NSMutableDictionary new];
        state.deadlines = [NSMutableDictionary new];
        state.waitingForRow = [NSMutableSet new];
        state.favoriteTitles = [NSMutableDictionary new];
        state.proposals = [NSMutableDictionary new];
        DPSet(surface, &DPTidyListStateKey, state);
    }
    if (state.scheduled) return;
    state.scheduled = YES;
    __weak NSView *list = surface;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 75 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        state.scheduled = NO;
        if (DPGet(list, &DPTidyListStateKey) == state) DPTidyScanList(list, state);
    });
}

static void DPTidyListLayout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTidyListLayout, self);
    DPTidyScheduleScan(self);
}

static void DPTidyInnerLayout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTidyInnerLayout, self);
    // The collection and Favorites dock can update without invalidating their parent.
    for (NSView *ancestor = self.superview; ancestor; ancestor = ancestor.superview)
        if (DPIsKind(ancestor, DPDiaTabList) || DPIsKind(ancestor, DPTidyStrip)) {
            DPTidyScheduleScan(ancestor);
            return;
        }
    // Horizontal Favorites live beside the strip rather than inside it.
    for (NSView *strip in DPFindViews(DPTidyStrip))
        if (strip.window == self.window) DPTidyScheduleScan(strip);
}

static void DPTidyResumeWindow(NSWindow *window) {
    if (!DPTidyTitlesEnabled() || !window.isKeyWindow) return;
    const char *surfaces[] = {DPDiaTabList, DPTidyStrip};
    for (NSUInteger index = 0; index < 2; index++)
        for (NSView *surface in DPFindViews(surfaces[index])) {
            DPTidyListState *state = DPGet(surface, &DPTidyListStateKey);
            if (surface.window == window && state.pending.count) DPTidyScheduleScan(surface);
        }
}

static void DPTidyCaptureWindowTitles(NSWindow *window) {
    if (!DPTidyTitlesEnabled() || !window.isKeyWindow) return;
    const char *surfaces[] = {DPDiaTabList, DPTidyStrip};
    for (NSUInteger index = 0; index < 2; index++)
        for (NSView *surface in DPFindViews(surfaces[index])) {
            DPTidyListState *state = DPGet(surface, &DPTidyListStateKey);
            if (state && surface.window == window) {
                state.draggedIdentifier = nil;
                state.draggedTitle = nil;
                state.plainTitles = DPTidyPlainTitles(surface);
            }
        }
}

static BOOL DPTidySendAction(NSApplication *self, SEL _cmd, SEL action, id target, id sender) {
    if (DPTidyTitlesEnabled() && [sender isKindOfClass:NSMenuItem.class]) {
        NSString *title = [(NSMenuItem *)sender title];
        if ([title isEqualToString:@"Pin"] || [title hasPrefix:@"Pin "])
            DPTidyCaptureWindowTitles(self.keyWindow);
    }
    return DPCallOriginal(DPTidySendAction, self, action, target, sender);
}

static void DPTidyTabDragged(NSView *self, SEL _cmd, NSEvent *event) {
    if (DPTidyTitlesEnabled() && self.window.isKeyWindow) {
        for (NSView *ancestor = self.superview; ancestor; ancestor = ancestor.superview) {
            DPTidyListState *state = DPGet(ancestor, &DPTidyListStateKey);
            if (!state || state.window != self.window) continue;
            NSString *identifier = DPTidyTabIdentifier(self);
            if (identifier.length) {
                state.draggedIdentifier = identifier;
                state.draggedTitle = DPTidyPlainTitle(self);
                state.draggedAt = NSProcessInfo.processInfo.systemUptime;
            }
            break;
        }
    }
    DPCallOriginal(DPTidyTabDragged, self, event);
}

static void DPTidyDragBegan(NSView *self, SEL _cmd, NSDraggingSession *session, NSPoint point) {
    DPTidyListState *state = DPGet(self, &DPTidyListStateKey);
    if (DPTidyTitlesEnabled() && state.window == self.window) {
        state.dragging = YES;
        state.plainTitles = DPTidyPlainTitles(self);
    }
    DPCallOriginal(DPTidyDragBegan, self, session, point);
}

static void DPTidyDragEnded(NSView *self, SEL _cmd, NSDraggingSession *session, NSPoint point, NSDragOperation operation) {
    DPCallOriginal(DPTidyDragEnded, self, session, point, operation);
    DPTidyListState *state = DPGet(self, &DPTidyListStateKey);
    state.dragging = NO;
    if (operation == NSDragOperationNone) {
        state.draggedIdentifier = nil;
        state.draggedTitle = nil;
    } else if (state.draggedIdentifier) {
        state.draggedAt = NSProcessInfo.processInfo.systemUptime;
    }
    DPTidyScheduleScan(self);
}

static BOOL DPTidyPerformDrop(NSView *self, SEL _cmd, id<NSDraggingInfo> info) {
    BOOL accepted = DPCallOriginal(DPTidyPerformDrop, self, info);
    if (accepted) DPTidyScheduleScan(self);
    return accepted;
}

void DPInstallTidyTabTitles(void) {
    DPInstallTidyRenameDialog();
    DPHook(DPDiaTabList, @selector(layout), (IMP)DPTidyListLayout);
    DPHook(DPTidyCollection, @selector(layout), (IMP)DPTidyInnerLayout);
    DPHook(DPTidyDock, @selector(layout), (IMP)DPTidyInnerLayout);
    DPHook(DPTidyStrip, @selector(layout), (IMP)DPTidyListLayout);
    DPHook(DPDiaTabView, @selector(mouseDragged:), (IMP)DPTidyTabDragged);
    const char *surfaces[] = {DPDiaTabList, DPTidyStrip};
    for (NSUInteger index = 0; index < 2; index++) {
        DPHook(surfaces[index], @selector(draggingSession:willBeginAtPoint:), (IMP)DPTidyDragBegan);
        DPHook(surfaces[index], @selector(draggingSession:endedAtPoint:operation:), (IMP)DPTidyDragEnded);
        DPHook(surfaces[index], @selector(performDragOperation:), (IMP)DPTidyPerformDrop);
    }
    DPOnLaunch(^{ DPHookClass(NSApp.class, @selector(sendAction:to:from:), (IMP)DPTidySendAction); });
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:nil
        usingBlock:^(NSNotification *note) { DPTidyResumeWindow(note.object); }];
    [NSNotificationCenter.defaultCenter addObserverForName:NSControlTextDidEndEditingNotification object:nil queue:nil
        usingBlock:^(NSNotification *note) { DPTidyResumeWindow(NSApp.keyWindow); }];
}
