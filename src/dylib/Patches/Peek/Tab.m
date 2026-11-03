#import "Patches/Peek/Peek.h"

// Reads a Swift property the Obj-C runtime hides. AXCoreUtilities ships it in every AppKit app; ProfileEmoji uses it too.
@interface NSObject (DPPeekSwiftFields)
- (id)safeSwiftValueForKey:(NSString *)key;
@end

static NSString *DPTabStateDesc(NSView *tab) {
    return [[[[tab safeSwiftValueForKey:@"viewModel"] safeSwiftValueForKey:@"stateSubject"] safeSwiftValueForKey:@"currentValue"] description];
}

static NSArray<NSView *> *DPAllTabs(void) {
    NSMutableArray<NSView *> *tabs = [NSMutableArray array];
    [tabs addObjectsFromArray:DPFindViews(DPDiaTab)];
    [tabs addObjectsFromArray:DPFindViews(DPDiaPinnedTab)];
    return tabs;
}

// A page's own id, which appears in its tab's content list.
static NSString *DPPeekPageID(id page) {
    for (NSString *key in @[@"identifier", @"id", @"contentID", @"contentId", @"uuid"]) {
        NSString *value = [[(NSObject *)page safeSwiftValueForKey:key] description];
        if (value.length >= 32 && [value containsString:@"-"]) return value;  // a UUID
    }
    return nil;
}

// The tab a peek came from: the one whose content list holds the source page, else the selected tab (its page stays
// selected while the peek floats over it). selectionStyle reads "none" when unselected and an adjacency style on the
// tabs either side of the selection, so a non-adjacent, non-"none" style is the selected tab.
static NSView *DPPeekOriginTab(NSWindow *window, id source) {
    NSString *sourceID = DPPeekPageID(source);
    NSView *fallback = nil;
    for (NSView *tab in DPAllTabs()) {
        if (tab.window != window) continue;
        id state = [[[tab safeSwiftValueForKey:@"viewModel"] safeSwiftValueForKey:@"stateSubject"] safeSwiftValueForKey:@"currentValue"];
        NSString *desc = [state description];
        if (sourceID && desc && [desc containsString:sourceID]) return tab;
        NSString *style = [[[state safeSwiftValueForKey:@"selectionStyle"] description] lowercaseString];
        if (!fallback && style && ![style containsString:@"none"] && ![style containsString:@"above"] && ![style containsString:@"below"]) fallback = tab;
    }
    return fallback;
}

// A content id from a tab's own state, used to recognise that tab again as the sidebar relays out and to tell when it
// has been closed. Pinned tabs don't list one, so they get no close-tracking (and never a false close).
static NSString *DPPeekTabContentKey(NSView *tab) {
    NSString *desc = DPTabStateDesc(tab);
    NSRange mark = [desc rangeOfString:@"contentIDs: ["];
    if (mark.location == NSNotFound) return nil;
    NSString *rest = [desc substringFromIndex:NSMaxRange(mark)];
    if (rest.length < 36) return nil;
    NSString *key = [rest substringToIndex:36];  // a UUID
    return [key containsString:@"-"] ? key : nil;
}

static NSView *DPPeekTabWithContent(NSWindow *window, NSString *key) {
    for (NSView *tab in DPAllTabs()) {
        if (tab.window != window) continue;
        NSString *desc = DPTabStateDesc(tab);
        if (desc && [desc containsString:key]) return tab;
    }
    return nil;
}

// A small 👀 marking the tab a peek came from. On a sidebar tab it hides while that tab is hovered, so Dia's close
// button (which shares the spot) stays usable; a pinned tab keeps it the whole time. It never takes clicks, and a timer
// keeps it on the tab as the sidebar relays out and closes the peek once the tab is gone.
@interface DPPeekTabBadge : NSView
@property (nonatomic, weak) DPPeekCard *peek;
@property (nonatomic, copy) NSString *contentKey;
@property (nonatomic) BOOL hidesOnHover;
@property (nonatomic, strong) NSTrackingArea *tabTracking;
@property (nonatomic, strong) NSTimer *watch;
@property (nonatomic) NSInteger misses;
@end

@implementation DPPeekTabBadge
- (NSView *)hitTest:(NSPoint)point { return nil; }  // Never steals a click from the tab or its close button.

- (void)viewDidMoveToSuperview {
    [super viewDidMoveToSuperview];
    if (self.tabTracking) { [self.tabTracking.owner removeTrackingArea:self.tabTracking]; self.tabTracking = nil; }
    if (self.superview && self.hidesOnHover) {
        self.tabTracking = [[NSTrackingArea alloc] initWithRect:self.superview.bounds
            options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil];
        [self.superview addTrackingArea:self.tabTracking];
    }
}

- (void)mouseEntered:(NSEvent *)event { if (self.hidesOnHover) self.hidden = YES; }
- (void)mouseExited:(NSEvent *)event { self.hidden = NO; }

- (void)watch:(NSTimer *)timer {
    if (!self.peek || self.peek.closing) { [self stop]; return; }
    if (!self.contentKey) return;  // No stable id for this tab: keep the badge, never auto-close.
    NSView *tab = DPPeekTabWithContent(self.peek.window, self.contentKey);
    if (tab) { self.misses = 0; if (self.superview != tab) [tab addSubview:self]; }
    else if (++self.misses >= 2) { [self stop]; [self.peek close:0]; }  // the tab was closed: close the peek too
}

- (void)stop { [self.watch invalidate]; self.watch = nil; }
@end

void DPPeekShowTabBadge(DPPeekCard *peek, id source, id<DPPeekPage> page) {
    NSView *tab = DPPeekOriginTab(peek.window, source);
    if (!tab) return;
    NSTextField *eyes = [NSTextField labelWithString:@"👀"];
    eyes.font = [NSFont systemFontOfSize:13];
    [eyes sizeToFit];
    CGFloat w = NSWidth(eyes.frame), h = NSHeight(eyes.frame);
    BOOL pinned = DPIsKind(tab, DPDiaPinnedTab);
    CGFloat x, y;
    NSAutoresizingMaskOptions resize;
    if (pinned) {  // perched on the top-right corner, overhanging a touch, like Arc
        x = NSMaxX(tab.bounds) - w + 5;
        y = tab.isFlipped ? -5 : NSMaxY(tab.bounds) - h + 5;
        resize = NSViewMinXMargin | (tab.isFlipped ? NSViewMaxYMargin : NSViewMinYMargin);
    } else {       // right end, centred
        x = NSMaxX(tab.bounds) - w - 6;
        y = NSMidY(tab.bounds) - h / 2;
        resize = NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin;
    }
    DPPeekTabBadge *badge = [[DPPeekTabBadge alloc] initWithFrame:NSMakeRect(x, y, w, h)];
    badge.autoresizingMask = resize;
    badge.peek = peek;
    badge.contentKey = DPPeekTabContentKey(tab);
    badge.hidesOnHover = !pinned;
    eyes.frame = badge.bounds;
    eyes.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [badge addSubview:eyes];
    [tab addSubview:badge];
    peek.tabBadge = badge;
    badge.watch = [NSTimer scheduledTimerWithTimeInterval:0.6 target:badge selector:@selector(watch:) userInfo:nil repeats:YES];
}

void DPPeekHideTabBadge(DPPeekCard *peek) {
    [(DPPeekTabBadge *)peek.tabBadge stop];
    [peek.tabBadge removeFromSuperview];
    peek.tabBadge = nil;
}
