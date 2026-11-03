// A new tab opens as Dia's own command bar, lifted out of the new tab page and laid over the page you were on.
// Tabs are found and switched through Dia's AppleScript objects.
#import "StdPatch/StdPatch.h"

extern DPPatch DPCommandBar, DPCommandBarBlur, DPCommandBarDarken;
static char DPOverlayKey, DPHomeKey, DPRecentKey, DPBlankKey;

static NSString *const DPHeightKey = @"commandBarHeight", *const DPDarknessKey = @"commandBarDarkness",
                *const DPBlurRadiusKey = @"commandBarBlurRadius", *const DPBlurWindowKey = @"commandBarBlurWindow";

@interface DPCommandBarOverlay : NSView
@property(weak) NSView *page, *panel;
@property(weak) NSWindow *host;
@property(strong) NSView *shade, *windowBlur;
@property(strong) id openedTab, returnTab, keyMonitor;
@property(strong) NSTimer *watch;
@property(copy) NSString *startURL;
@property CGFloat collapsedHeight;
@property BOOL picked, overBlank;
@end

@interface NSObject (DPCAFilter)
+ (id)filterWithType:(NSString *)type;
@end

static void DPCancelCommandBar(DPCommandBarOverlay *overlay);
static void DPPlaceShade(DPCommandBarOverlay *overlay);

#pragma mark Settings

static NSUserDefaults *DPSettings(void) {
    static NSUserDefaults *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return settings;
}

static double DPTuned(NSString *key) {
    NSDictionary *defaults = @{ DPHeightKey : @0.3, DPDarknessKey : @0.24, DPBlurRadiusKey : @4, DPBlurWindowKey : @NO };
    return [([DPSettings() objectForKey:key] ?: defaults[key]) doubleValue];
}

static NSMenuItem *DPMenuItemTitled(NSMenu *menu, NSString *title) {
    for (NSMenuItem *item in menu.itemArray) {
        NSMenuItem *found = [item.title isEqual:title] ? item : DPMenuItemTitled(item.submenu, title);
        if (found) return found;
    }
    return nil;
}

static BOOL DPIsShortcut(NSEvent *event, NSString *menuTitle) {
    if (event.type != NSEventTypeKeyDown && event.type != NSEventTypeKeyUp) return NO;
    NSMenuItem *item = DPMenuItemTitled(NSApp.mainMenu, menuTitle);
    NSEventModifierFlags mods = NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl;
    return item.keyEquivalent.length && (event.modifierFlags & mods) == item.keyEquivalentModifierMask
        && [event.charactersIgnoringModifiers caseInsensitiveCompare:item.keyEquivalent] == NSOrderedSame;
}

#pragma mark Tabs

static id DPScriptWindow(NSWindow *window) {
    for (id scripted in [(id)NSApp.delegate valueForKey:@"appleScriptWindows"])
        if ([[scripted valueForKey:@"windowId"] isEqual:window.identifier]) return scripted;
    return nil;
}

static id DPScriptTab(NSWindow *window, NSString *tabID) {
    for (id tab in [DPScriptWindow(window) valueForKey:@"appleScriptTabs"])
        if ([[tab valueForKey:@"tabId"] isEqual:tabID]) return tab;
    return nil;
}

static NSString *DPTabID(id tab) { return [tab valueForKey:@"tabId"]; }
static NSString *DPActiveTabID(NSWindow *window) { return DPTabID([DPScriptWindow(window) valueForKey:@"activeTab"]); }
static void DPFocusTab(id tab) { [tab performSelector:@selector(focus:) withObject:nil]; }
static void DPCloseTab(id tab) { [tab performSelector:@selector(close:) withObject:nil]; }

// The last two tabs shown in the window, oldest first.
static void DPNoteActiveTab(NSWindow *window) {
    NSString *active = DPActiveTabID(window);
    NSArray *recent = DPGet(window, &DPRecentKey);
    if (active && ![recent.lastObject isEqual:active]) DPSet(window, &DPRecentKey, recent.count ? @[ recent.lastObject, active ] : @[ active ]);
}

static NSString *DPPreviousTabID(NSWindow *window) {
    NSArray *recent = DPGet(window, &DPRecentKey);
    return recent.count > 1 ? recent.firstObject : nil;
}

// Tabs left blank, without the bar, after the window's last tab closed.
static NSMutableSet<NSString *> *DPBlanks(NSWindow *window) {
    NSMutableSet *blanks = DPGet(window, &DPBlankKey);
    if (!blanks && window) DPSet(window, &DPBlankKey, blanks = [NSMutableSet set]);
    return blanks;
}

#pragma mark Overlay

static NSView *DPPanelIn(NSView *page) {
    return DPFindView(page, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAssistantPanel); });
}

static NSTextView *DPBarText(DPCommandBarOverlay *overlay) {
    return (NSTextView *)DPFindView(overlay.panel, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
}

static void DPFocusBar(DPCommandBarOverlay *overlay) {
    NSTextView *text = DPBarText(overlay);
    if (text && overlay.host.firstResponder != text) [overlay.host makeFirstResponder:text];
}

// Like NSWindow.center(), macOS center leaves a share of the screen's spare height above the bar.
static NSPoint DPBarOrigin(DPCommandBarOverlay *overlay, NSSize bar) {
    NSRect bounds = overlay.bounds;
    if (![DPChoice(&DPCommandBar) isEqual:@"macos"] || !overlay.window.screen)
        return NSMakePoint(NSMidX(bounds) - bar.width / 2, NSMidY(bounds) - bar.height / 2);
    NSRect screen = overlay.window.screen.visibleFrame;
    NSPoint topLeft = NSMakePoint(NSMidX(screen) - bar.width / 2, NSMaxY(screen) - (NSHeight(screen) - bar.height) * DPTuned(DPHeightKey));
    return [overlay convertPoint:[overlay.window convertPointFromScreen:topLeft] fromView:nil];
}

@implementation DPCommandBarOverlay

- (BOOL)isFlipped { return YES; }

- (NSRect)frameForPanelSize:(NSSize)size {
    if (!self.collapsedHeight) self.collapsedHeight = size.height;
    NSPoint origin = DPBarOrigin(self, NSMakeSize(size.width, self.collapsedHeight));
    NSRect inside = NSInsetRect(self.bounds, 12, 12);
    CGFloat x = MAX(MIN(origin.x, NSMaxX(inside) - size.width), NSMinX(inside));
    CGFloat y = MAX(MIN(origin.y, NSMaxY(inside) - size.height), NSMinY(inside));
    return NSMakeRect(round(x), round(y), size.width, size.height);
}

- (void)layout {
    [super layout];
    if (self.panel) self.panel.frame = [self frameForPanelSize:self.panel.frame.size];
    DPPlaceShade(self);
}

- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    return !hit || (self.panel && [hit isDescendantOf:self.panel]) ? hit : self;
}

- (void)mouseDown:(NSEvent *)event { DPCancelCommandBar(self); }
- (void)rightMouseDown:(NSEvent *)event {}
- (void)scrollWheel:(NSEvent *)event {}

@end

#pragma mark Shade

// The only blur that reaches web content, which Dia's GPU process draws.
static CALayer *DPBlurLayer(void) {
    CALayer *backdrop = [NSClassFromString(@"CABackdropLayer") new];
    id blur = [(id)NSClassFromString(@"CAFilter") filterWithType:@"gaussianBlur"];
    if (!backdrop || !blur) return nil;
    [blur setValue:@(DPTuned(DPBlurRadiusKey)) forKey:@"inputRadius"];
    [blur setValue:@YES forKey:@"inputNormalizeEdges"];
    backdrop.filters = @[ blur ];
    return backdrop;
}

// The page's rounded card: the visible content pane, or its ancestor that clips it.
static NSView *DPCardIn(NSWindow *window) {
    NSView *pane = DPFindView(window.contentView, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaContentPane) && !view.isHiddenOrHasHiddenAncestor; });
    for (NSView *view = pane; view && view != window.contentView; view = view.superview)
        if (view.layer.cornerRadius > 0 && view.layer.maskedCorners && view.layer.masksToBounds) return view;
    return pane;
}

static NSView *DPLayerView(NSRect frame, NSArray<CALayer *> *layers) {
    NSView *view = [[NSView alloc] initWithFrame:frame];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view.wantsLayer = YES;
    for (CALayer *layer in layers) {
        layer.frame = view.bounds;
        layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
        [view.layer addSublayer:layer];
    }
    return view;
}

// Inside the card, so it moves and clips with it as the sidebar slides.
static void DPPlaceShade(DPCommandBarOverlay *overlay) {
    NSView *card = DPCardIn(overlay.host);
    if (!card || overlay.shade.superview == card) return;
    overlay.shade.frame = card.bounds;
    [card addSubview:overlay.shade];
}

static void DPShowShade(DPCommandBarOverlay *overlay) {
    [overlay.shade removeFromSuperview];
    [overlay.windowBlur removeFromSuperview];
    overlay.shade = overlay.windowBlur = nil;
    NSString *returnID = DPTabID(overlay.returnTab);
    if (!returnID || [DPBlanks(overlay.host) containsObject:returnID]) return;

    CALayer *blur = DPCommandBarBlur.on ? DPBlurLayer() : nil;
    NSMutableArray<CALayer *> *layers = [NSMutableArray array];
    if (blur && DPTuned(DPBlurWindowKey)) {
        overlay.windowBlur = DPLayerView(overlay.bounds, @[ blur ]);
        [overlay addSubview:overlay.windowBlur positioned:NSWindowBelow relativeTo:overlay.panel];
    } else if (blur) {
        [layers addObject:blur];
    }
    if (DPCommandBarDarken.on) {
        CALayer *dim = [CALayer layer];
        dim.backgroundColor = [NSColor colorWithWhite:0 alpha:DPTuned(DPDarknessKey)].CGColor;
        [layers addObject:dim];
    }
    overlay.shade = DPLayerView(NSZeroRect, layers);
    DPPlaceShade(overlay);
}

#pragma mark Presenting

// Relaid out so the toolbar options that keep it on new tab pages see the page come and go.
static void DPHidePage(NSView *page, BOOL hidden) {
    page.hidden = hidden;
    for (NSView *view = page.superview; view; view = view.superview)
        if (DPIsKind(view, DPDiaContentPane)) view.needsLayout = YES;
}

static void DPMakeBlank(NSView *page) {
    NSString *active = DPActiveTabID(page.window);
    if (!active) return;
    [DPBlanks(page.window) addObject:active];
    DPSet(page, &DPBlankKey, @YES);
    DPHidePage(page, YES);
}

static NSView *DPBlankPage(NSWindow *window) {
    return DPFindView(window.contentView, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaNewTabPage) && DPGet(view, &DPBlankKey); });
}

// Returns the tab the bar opened, still open.
static id DPDismissCommandBar(DPCommandBarOverlay *overlay) {
    [overlay.watch invalidate];
    if (overlay.keyMonitor) [NSEvent removeMonitor:overlay.keyMonitor];
    overlay.keyMonitor = nil;
    [overlay.shade removeFromSuperview];
    if (!overlay.host) return nil;
    if (DPGet(overlay.host, &DPOverlayKey) == overlay) DPSet(overlay.host, &DPOverlayKey, nil);
    overlay.host = nil;
    NSView *page = overlay.page, *panel = overlay.panel, *home = DPGet(panel, &DPHomeKey);
    DPSet(page, &DPOverlayKey, nil);
    DPSet(panel, &DPHomeKey, nil);
    if (panel && home) [home addSubview:panel];
    DPHidePage(page, NO);
    home.needsLayout = YES;
    [overlay removeFromSuperview];
    return overlay.openedTab;
}

static void DPCancelCommandBar(DPCommandBarOverlay *overlay) {
    NSView *page = overlay.page;
    BOOL overBlank = overlay.overBlank;
    id tab = DPDismissCommandBar(overlay);
    if (overBlank) DPMakeBlank(page);
    else if (tab) DPCloseTab(tab);
}

static void DPWatchNewTab(DPCommandBarOverlay *overlay) {
    NSWindow *window = overlay.host;
    NSView *frame = window.contentView.superview;
    if (!window) return (void)DPDismissCommandBar(overlay);
    if (overlay.superview != frame) {  // Dia rebuilds the frame view as it restores a window at launch.
        overlay.frame = frame.bounds;
        [frame addSubview:overlay positioned:NSWindowAbove relativeTo:nil];
    }
    DPPlaceShade(overlay);
    id tab = DPScriptTab(window, DPTabID(overlay.openedTab));
    if (!tab) return (void)DPDismissCommandBar(overlay);
    // A chat loads no page; Dia empties the bar once it has taken what was typed.
    BOOL taken = overlay.picked && !DPBarText(overlay).string.length;
    NSString *url = [tab valueForKey:@"URL"];
    if (!taken && (url == overlay.startURL || [url isEqual:overlay.startURL])) return;
    DPDismissCommandBar(overlay);
    DPFocusTab(tab);
}

static void DPWatchSoon(DPCommandBarOverlay *overlay, int checks) {
    __weak DPCommandBarOverlay *weak = overlay;
    if (checks && overlay.host)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            if (!weak.host) return;
            DPWatchNewTab(weak);
            DPWatchSoon(weak, checks - 1);
        });
}

static id DPWatchKeys(DPCommandBarOverlay *overlay) {
    __weak DPCommandBarOverlay *weak = overlay;
    return [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown | NSEventMaskLeftMouseUp handler:^NSEvent *(NSEvent *event) {
        DPCommandBarOverlay *overlay = weak;
        if (!overlay || event.window != overlay.host) return event;
        if (event.type == NSEventTypeLeftMouseUp || event.keyCode == 36 || event.keyCode == 76) {
            overlay.picked = overlay.picked || DPBarText(overlay).string.length > 0;
            DPWatchSoon(overlay, 60);
            return event;
        }
        BOOL escape = event.keyCode == 53;
        BOOL close = (event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagCommand
                     && [event.charactersIgnoringModifiers isEqualToString:@"w"];
        if (!escape && !close) return event;
        NSRect bar = [overlay.host convertRectToScreen:[overlay.panel convertRect:overlay.panel.bounds toView:nil]];
        for (NSWindow *child in overlay.host.childWindows)  // Like the bar's @ menu, which Escape closes first.
            if (escape && child.visible && NSIntersectsRect(child.frame, bar)) return event;
        DPCancelCommandBar(overlay);
        return nil;
    }];
}

// Going back to the page before Dia first draws the new tab keeps the new tab page from flashing up, but Dia, still
// switching tabs, takes the page's web view out of the window: the page shows, yet takes no clicks. So the web view is
// put back before the window draws. Dia also titles the window after the new tab once its switch is done.
static void DPGoBack(DPCommandBarOverlay *overlay) {
    NSView *web = DPFindView(overlay.host.contentView, ^BOOL(NSView *view) { return DPIsKind(view, "WebContentsHostView") && !view.isHiddenOrHasHiddenAncestor; });
    NSView *paneHost = web.superview;
    DPFocusTab(overlay.returnTab);
    if (web) {
        CFRunLoopObserverRef beforeDraw = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, NO, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            if (web.superview || !paneHost.window) return;
            [paneHost addSubview:web positioned:NSWindowBelow relativeTo:nil];
            [NSLayoutConstraint activateConstraints:@[
                [web.topAnchor constraintEqualToAnchor:paneHost.topAnchor], [web.bottomAnchor constraintEqualToAnchor:paneHost.bottomAnchor],
                [web.leadingAnchor constraintEqualToAnchor:paneHost.leadingAnchor], [web.trailingAnchor constraintEqualToAnchor:paneHost.trailingAnchor],
            ]];
        });
        CFRunLoopAddObserver(CFRunLoopGetMain(), beforeDraw, kCFRunLoopCommonModes);
        CFRelease(beforeDraw);
    }
    __weak DPCommandBarOverlay *weak = overlay;
    dispatch_async(dispatch_get_main_queue(), ^{ if (weak.superview) DPFocusBar(weak); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (!weak.superview) return;
        DPFocusTab(weak.returnTab);
        dispatch_async(dispatch_get_main_queue(), ^{ if (weak.superview) DPFocusBar(weak); });
    });
}

// Over a blank tab, the bar opens on that tab's own page, with nothing to go back to.
static void DPPresentCommandBar(NSView *page, BOOL overBlank) {
    NSWindow *window = page.window;
    NSView *frame = window.contentView.superview, *panel = DPPanelIn(page);
    id openedTab = [DPScriptWindow(window) valueForKey:@"activeTab"];
    if (!DPCommandBar.on || !panel || !frame || !openedTab || DPGet(page, &DPOverlayKey)) return;
    NSString *openedID = DPTabID(openedTab), *returnID = DPPreviousTabID(window);
    NSArray *recent = DPGet(window, &DPRecentKey);
    if (![recent.lastObject isEqual:openedID]) returnID = recent.lastObject;
    if (overBlank) {
        returnID = nil;
        [DPBlanks(window) removeObject:openedID];
        DPSet(page, &DPBlankKey, nil);
    }

    DPCommandBarOverlay *overlay = [[DPCommandBarOverlay alloc] initWithFrame:frame.bounds];
    overlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    overlay.overBlank = overBlank;
    overlay.page = page;
    overlay.panel = panel;
    overlay.host = window;
    overlay.openedTab = openedTab;
    overlay.startURL = [openedTab valueForKey:@"URL"];
    overlay.returnTab = returnID ? DPScriptTab(window, returnID) : nil;
    [frame addSubview:overlay positioned:NSWindowAbove relativeTo:nil];
    DPSet(page, &DPOverlayKey, overlay);
    DPSet(window, &DPOverlayKey, overlay);
    DPSet(panel, &DPHomeKey, panel.superview);
    [overlay addSubview:panel];
    DPShowShade(overlay);
    panel.frame = [overlay frameForPanelSize:panel.frame.size];
    DPHidePage(page, YES);
    DPFocusBar(overlay);

    overlay.keyMonitor = DPWatchKeys(overlay);
    __weak DPCommandBarOverlay *weak = overlay;
    overlay.watch = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        if (weak) DPWatchNewTab(weak); else [timer invalidate];
    }];
    if (overlay.returnTab) DPGoBack(overlay);
}

static BOOL DPOpenOverBlank(NSWindow *window) {
    if (!DPCommandBar.on || ![DPBlanks(window) containsObject:DPActiveTabID(window)]) return NO;
    NSView *page = DPBlankPage(window);
    if (page) DPPresentCommandBar(page, YES);
    return page != nil;
}

static void DPCloseLeftBlank(NSWindow *window) {
    if (!window || DPGet(window, &DPOverlayKey)) return;
    NSMutableSet<NSString *> *blanks = DPBlanks(window);
    NSString *previous = DPPreviousTabID(window), *latest = [DPGet(window, &DPRecentKey) lastObject];
    id blank = [blanks containsObject:previous] && ![blanks containsObject:latest] ? DPScriptTab(window, previous) : nil;
    if (!blank || !DPScriptTab(window, latest)) return;
    [blanks removeObject:previous];
    DPCloseTab(blank);
}

#pragma mark Hooks

static void DPPanel_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    if ([self.superview isKindOfClass:DPCommandBarOverlay.class]) frame = [(DPCommandBarOverlay *)self.superview frameForPanelSize:frame.size];
    DPCallOriginal(DPPanel_setFrame, self, frame);
}

static DPCommandBarOverlay *DPOverlayAbove(NSView *view) {
    while (view && ![view isKindOfClass:DPCommandBarOverlay.class]) view = view.superview;
    return (DPCommandBarOverlay *)view;
}

// The new tab page sized the bar to its suggestions; out of it, the bar is sized here, with Dia's 8 points below them.
static void DPSuggestions_invalidateIntrinsicContentSize(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSuggestions_invalidateIntrinsicContentSize, self);
    DPCommandBarOverlay *overlay = DPOverlayAbove(self);
    if (!overlay) return;
    __weak NSView *suggestions = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSView *panel = overlay.panel;
        CGFloat height = suggestions.intrinsicContentSize.height, want = overlay.collapsedHeight + height + (height > 0 ? 8 : 0);
        if (!panel || height < 0 || NSHeight(panel.frame) == want) return;
        panel.frame = [overlay frameForPanelSize:NSMakeSize(NSWidth(panel.frame), want)];
        for (NSView *view = suggestions.superview; view && view != panel; view = view.superview) {
            view.frame = NSMakeRect(0, 0, NSWidth(view.frame), want);
            view.needsLayout = YES;
        }
        [panel layoutSubtreeIfNeeded];
    });
}

// "Add tabs or files" opens its menu only on a showing new tab page; typing @ opens the same menu from the bar.
static void DPCapability_mouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    DPCommandBarOverlay *overlay = DPOverlayAbove(self);
    if (!overlay.returnTab) return DPCallOriginal(DPCapability_mouseDown, self, event);
    DPFocusBar(overlay);
    [DPBarText(overlay) insertText:@"@" replacementRange:DPBarText(overlay).selectedRange];
}

static void DPNewTabButton_mouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    if (!DPOpenOverBlank(self.window)) DPCallOriginal(DPNewTabButton_mouseDown, self, event);
}

static NSEvent *DPNewTabKey(NSEvent *event) {
    NSWindow *window = event.window;
    if (!DPCommandBar.on || !window || !DPIsShortcut(event, @"New Tab")) return event;
    DPCommandBarOverlay *overlay = DPGet(window, &DPOverlayKey);
    if (overlay) DPFocusBar(overlay);
    return overlay || DPOpenOverBlank(window) ? nil : event;
}

static void DPContentPane_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPContentPane_viewDidMoveToWindow, self);
    __weak NSWindow *window = self.window;
    if (!window) return;
    DPNoteActiveTab(window);
    dispatch_async(dispatch_get_main_queue(), ^{ DPCloseLeftBlank(window); });
}

static void DPNewTabPage_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNewTabPage_viewDidMoveToWindow, self);
    NSWindow *window = self.window;
    if (!window) return;
    DPNoteActiveTab(window);
    if (!DPCommandBar.on) return;
    NSString *active = DPActiveTabID(window), *previous = DPPreviousTabID(window);
    NSMutableSet<NSString *> *blanks = DPBlanks(window);
    DPCommandBarOverlay *overlay = DPGet(window, &DPOverlayKey);
    if (overlay && [active isEqual:DPTabID(overlay.openedTab)]) {
        if (overlay.returnTab) dispatch_async(dispatch_get_main_queue(), ^{ if (overlay.host) DPFocusTab(overlay.returnTab); });
        return;
    }
    // Dia opens the tab that replaces a closing last tab before closing it, so a close is told by its shortcut, or
    // afterwards by the tab before being gone.
    BOOL closing = DPIsShortcut(NSApp.currentEvent, @"Close Tab") || (previous && !DPScriptTab(window, previous));
    if (active && ([blanks containsObject:active] || closing)) {
        DPMakeBlank(self);
        if (overlay.returnTab && !DPScriptTab(window, DPTabID(overlay.returnTab))) DPCancelCommandBar(overlay);
        return;
    }
    if (overlay) DPCancelCommandBar(overlay);
    id blank = [blanks containsObject:previous] ? DPScriptTab(window, previous) : nil;
    if (blank) {
        [blanks removeObject:previous];
        DPCloseTab(blank);
    }
    // The page has no size until its pane lays it out, and the bar takes its size from it.
    NSView *pane = self.superview;
    while (pane && !DPIsKind(pane, DPDiaContentPane)) pane = pane.superview;
    [pane layoutSubtreeIfNeeded];
    DPPresentCommandBar(self, blank != nil);
}

#pragma mark Patch

static void DPApplyCommandBar(DPPatch *patch) {
    BOOL on = DPCommandBar.on;
    for (NSWindow *window in NSApp.windows) {
        if (!on) DPSet(window, &DPBlankKey, nil);
        DPCommandBarOverlay *overlay = DPGet(window, &DPOverlayKey);
        if (!overlay) continue;
        if (on) {
            DPShowShade(overlay);
            continue;
        }
        id tab = DPDismissCommandBar(overlay);
        if (tab && overlay.returnTab) DPFocusTab(tab);
    }
    for (NSView *page in DPFindViews(DPDiaNewTabPage)) {
        BOOL blank = DPGet(page, &DPBlankKey) != nil;
        if (on && !blank) DPPresentCommandBar(page, NO);
        if (!on && blank) {
            DPSet(page, &DPBlankKey, nil);
            DPHidePage(page, NO);
        }
    }
}

static NSString *DPVerifyCommandBar(DPPatch *patch) {
    for (NSView *page in DPFindViews(DPDiaNewTabPage)) {
        DPCommandBarOverlay *overlay = DPGet(page, &DPOverlayKey);
        BOOL blank = DPGet(page, &DPBlankKey) != nil;
        if (blank && !page.hidden) return @"a blank tab shows its new tab page";
        if (DPCommandBar.on && !overlay && !blank) return @"a new tab page shows without the bar over it";
        if (overlay && overlay.panel.superview != overlay) return @"the bar isn't on the overlay";
    }
    for (NSWindow *window in NSApp.windows)
        if (!DPCommandBar.on && DPGet(window, &DPOverlayKey)) return @"the bar is still open";
    return nil;
}

static void DPInstallCommandBar(void) {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) { return DPNewTabKey(event); }];
    DPHook(DPDiaNewTabButton, @selector(mouseDown:), (IMP)DPNewTabButton_mouseDown);
    DPHook(DPDiaContentPane, @selector(viewDidMoveToWindow), (IMP)DPContentPane_viewDidMoveToWindow);
    DPHook(DPDiaNewTabPage, @selector(viewDidMoveToWindow), (IMP)DPNewTabPage_viewDidMoveToWindow);
    DPHook(DPDiaAssistantPanel, @selector(setFrame:), (IMP)DPPanel_setFrame);
    DPHook(DPDiaCommandBarSuggestions, @selector(invalidateIntrinsicContentSize), (IMP)DPSuggestions_invalidateIntrinsicContentSize);
    DPHook(DPDiaCapabilityButton, @selector(mouseDown:), (IMP)DPCapability_mouseDown);
}

#pragma mark Settings rows

@interface DPCommandBarTuneRow : NSStackView <NSTextFieldDelegate>
@property(copy) NSString *key;
@property double scale;  // From the saved value to the shown one.
@property NSSlider *slider;
@property NSTextField *field;
@end

@implementation DPCommandBarTuneRow

- (void)tune:(NSControl *)control {
    double shown = [control isKindOfClass:NSSwitch.class] ? ((NSSwitch *)control).state
                                                          : round(MIN(MAX(control.doubleValue, 0), self.slider.maxValue));
    self.slider.doubleValue = shown;
    self.field.doubleValue = shown;
    [DPSettings() setDouble:shown / self.scale forKey:self.key];
    for (NSWindow *window in NSApp.windows) {
        DPCommandBarOverlay *overlay = DPGet(window, &DPOverlayKey);
        if (overlay) DPShowShade(overlay);
        overlay.needsLayout = YES;
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    NSNumber *step = @{ @"moveUp:" : @1, @"moveDown:" : @-1, @"moveUpAndModifySelection:" : @10, @"moveDownAndModifySelection:" : @-10 }[NSStringFromSelector(command)];
    if (!step) return NO;
    self.field.doubleValue = textView.string.doubleValue + step.doubleValue;
    [self tune:self.field];
    [textView selectAll:nil];
    return YES;
}

@end

static DPCommandBarTuneRow *DPTuneRow(NSString *title, NSString *key, double scale, NSView *control) {
    NSTextField *label = [NSTextField labelWithString:title];
    [label setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    DPCommandBarTuneRow *row = [DPCommandBarTuneRow stackViewWithViews:@[ label, control ]];
    row.key = key;
    row.scale = scale;
    return row;
}

static NSView *DPSliderRow(NSString *title, NSString *key, double max, double scale, NSString *unit) {
    double shown = round(DPTuned(key) * scale);
    NSSlider *slider = [NSSlider sliderWithValue:shown minValue:0 maxValue:max target:nil action:@selector(tune:)];
    [slider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSNumberFormatter *whole = [NSNumberFormatter new];
    whole.maximumFractionDigits = 0;
    NSTextField *field = [NSTextField textFieldWithString:@""];
    field.formatter = whole;
    field.doubleValue = shown;
    field.alignment = NSTextAlignmentRight;
    field.action = @selector(tune:);
    [field.widthAnchor constraintEqualToConstant:44].active = YES;
    NSStackView *controls = [NSStackView stackViewWithViews:@[ slider, field, [NSTextField labelWithString:unit] ]];

    DPCommandBarTuneRow *row = DPTuneRow(title, key, scale, controls);
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    [controls.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    row.slider = slider;
    row.field = field;
    slider.target = field.target = field.delegate = row;
    return row;
}

static NSView *DPSwitchRow(NSString *title, NSString *key) {
    NSSwitch *toggle = [NSSwitch new];
    toggle.state = DPTuned(key) ? NSControlStateValueOn : NSControlStateValueOff;
    toggle.action = @selector(tune:);
    DPCommandBarTuneRow *row = DPTuneRow(title, key, 1, toggle);
    row.distribution = NSStackViewDistributionFill;
    toggle.target = row;
    return row;
}

static NSArray<NSView *> *DPCommandBarRows(void) {
    return @[
        DPSliderRow(@"Room above the bar in macOS center", DPHeightKey, 50, 100, @"%"),
        DPSliderRow(@"Darkness", DPDarknessKey, 80, 100, @"%"),
        DPSliderRow(@"Blur radius", DPBlurRadiusKey, 60, 1, @"pt"),
        DPSwitchRow(@"Blur the sidebar too", DPBlurWindowKey),
    ];
}

static NSMenu *DPCommandBarPositions(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Position"];
    for (NSArray *item in @[ @[ @"macOS center", @"macos" ], @[ @"Center of the window", @"window" ] ]) {
        NSMenuItem *entry = [[NSMenuItem alloc] initWithTitle:item[0] action:nil keyEquivalent:@""];
        entry.representedObject = item[1];
        [menu addItem:entry];
    }
    return menu;
}

DP_PATCH(DPCommandBar) {
    .key = @"commandBar",
    .order = 86,
    .title = @"Command bar",
    .detail = @"Open a new tab as Dia's command bar over the page you're on, instead of as a new tab page, like Arc. Pick something to open it in a new tab, or press Escape or click outside to go back.",
    .symbol = @"command",
    .tint = @"systemIndigoColor",
    .section = @"Tabs",
    .classes = DPClasses(DPDiaContentPane, DPDiaNewTabPage, DPDiaAssistantPanel, DPDiaCommandBarSuggestions),
    .choice = @"commandBarPosition",
    .defaultChoice = @"macos",
    .choices = DPCommandBarPositions,
    .rows = DPCommandBarRows,
    .install = DPInstallCommandBar,
    .apply = DPApplyCommandBar,
    .verify = DPVerifyCommandBar,
};

DP_PATCH(DPCommandBarBlur) {
    .key = @"commandBarBlur",
    .defaultOn = YES,
    .order = 87,
    .title = @"Blur the page behind",
    .detail = @"Blur the page behind the command bar.",
    .symbol = @"drop",
    .tint = @"systemIndigoColor",
    .section = @"Tabs",
    .requires = @"commandBar",
    .apply = DPApplyCommandBar,
};

DP_PATCH(DPCommandBarDarken) {
    .key = @"commandBarDarken",
    .defaultOn = YES,
    .order = 88,
    .title = @"Darken the page behind",
    .detail = @"Darken the page behind the command bar.",
    .symbol = @"moon",
    .tint = @"systemIndigoColor",
    .section = @"Tabs",
    .requires = @"commandBar",
    .apply = DPApplyCommandBar,
};
