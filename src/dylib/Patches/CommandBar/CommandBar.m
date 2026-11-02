// A new tab opens as Dia's own command bar over the page you were on, instead of as a new tab page. The tab still
// opens, so the bar, its suggestions and what it opens are all Dia's: the bar is lifted out of the new tab page, and
// the page you were on comes back under it while the new tab waits behind. Picking something loads it in the new tab,
// which then comes forward; cancelling closes it. Tabs are found and switched through Dia's AppleScript objects.
#import "StdPatch/StdPatch.h"

extern DPPatch DPCommandBar, DPCommandBarBlur, DPCommandBarDarken;
static char DPOverlayKey, DPHomeKey, DPRecentKey;

@interface DPCommandBarOverlay : NSView
@property(weak) NSView *page, *panel;
@property(strong) NSView *shade;
@property(strong) id openedTab, returnTab;
@property(copy) NSString *startURL;
@property CGFloat collapsedHeight;
@property(strong) id keyMonitor;
@property(strong) NSTimer *watch;
@property(weak) NSWindow *host;
@property BOOL picked;
@end

static void DPCancelCommandBar(DPCommandBarOverlay *overlay);

@interface NSObject (DPCAFilter)
+ (id)filterWithType:(NSString *)type;
@end

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

static NSString *DPActiveTabID(NSWindow *window) { return [[DPScriptWindow(window) valueForKey:@"activeTab"] valueForKey:@"tabId"]; }

// The tab shown before the current one, kept per window as tabs come and go.
static void DPNoteActiveTab(NSWindow *window) {
    NSString *active = DPActiveTabID(window);
    NSArray *recent = DPGet(window, &DPRecentKey);
    if (active && ![recent.lastObject isEqual:active]) DPSet(window, &DPRecentKey, recent.count ? @[ recent.lastObject, active ] : @[ active ]);
}

static void DPFocusTab(id tab) { [tab performSelector:@selector(focus:) withObject:nil]; }
static void DPCloseTab(id tab) { [tab performSelector:@selector(close:) withObject:nil]; }

#pragma mark Overlay

static NSView *DPPanelIn(NSView *page) {
    return DPFindView(page, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAssistantPanel); });
}

// How much of the room above and below the bar macOS center leaves above it. Debug in Settings tunes it.
static CGFloat DPBarHeight(void) {
    NSNumber *saved = [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] objectForKey:@"commandBarHeight"];
    return saved ? saved.doubleValue : 0.25;
}

// The bar's top left before suggestions open. macOS centres a window on the screen with a quarter of the room left
// above it and three quarters below, like NSWindow.center(); the window's centre is its middle.
static NSPoint DPBarOrigin(DPCommandBarOverlay *overlay, NSSize bar) {
    NSRect bounds = overlay.bounds;
    if (![DPChoice(&DPCommandBar) isEqual:@"macos"] || !overlay.window.screen)
        return NSMakePoint(NSMidX(bounds) - bar.width / 2, NSMidY(bounds) - bar.height / 2);
    NSRect visible = overlay.window.screen.visibleFrame;
    NSPoint topLeft = NSMakePoint(NSMinX(visible) + (NSWidth(visible) - bar.width) / 2, NSMaxY(visible) - (NSHeight(visible) - bar.height) * DPBarHeight());
    return [overlay convertPoint:[overlay.window convertPointFromScreen:topLeft] fromView:nil];
}

@implementation DPCommandBarOverlay

- (BOOL)isFlipped { return YES; }

// The bar's top stays put while its suggestions grow below, kept inside the window.
- (NSRect)frameForPanelSize:(NSSize)size {
    if (!self.collapsedHeight) self.collapsedHeight = size.height;
    NSPoint origin = DPBarOrigin(self, NSMakeSize(size.width, self.collapsedHeight));
    NSRect bounds = NSInsetRect(self.bounds, 12, 12);
    CGFloat x = MAX(MIN(origin.x, NSMaxX(bounds) - size.width), NSMinX(bounds));
    CGFloat y = MAX(MIN(origin.y, NSMaxY(bounds) - size.height), NSMinY(bounds));
    return NSMakeRect(round(x), round(y), size.width, size.height);
}

- (void)layout {
    [super layout];
    if (self.panel) self.panel.frame = [self frameForPanelSize:self.panel.frame.size];
}

// Only the bar takes the mouse; anywhere else cancels.
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    if (!hit) return nil;
    return self.panel && [hit isDescendantOf:self.panel] ? hit : self;
}

- (void)mouseDown:(NSEvent *)event { DPCancelCommandBar(self); }
- (void)rightMouseDown:(NSEvent *)event {}
- (void)scrollWheel:(NSEvent *)event {}

@end

// A backdrop layer, what NSVisualEffectView blurs with, is the only blur that reaches the page: Dia's GPU process draws
// it, and the window server composites it in.
static CALayer *DPBlurLayer(void) {
    CALayer *backdrop = [NSClassFromString(@"CABackdropLayer") new];
    id blur = [(id)NSClassFromString(@"CAFilter") filterWithType:@"gaussianBlur"];
    if (!backdrop || !blur) return nil;
    [blur setValue:@16 forKey:@"inputRadius"];
    [blur setValue:@YES forKey:@"inputNormalizeEdges"];
    backdrop.filters = @[ blur ];
    return backdrop;
}

static void DPShowShade(DPCommandBarOverlay *overlay) {
    NSView *shade = [[NSView alloc] initWithFrame:overlay.bounds];
    shade.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    shade.wantsLayer = YES;
    NSMutableArray *layers = [NSMutableArray array];
    if (DPCommandBarBlur.on && DPBlurLayer()) [layers addObject:DPBlurLayer()];
    if (DPCommandBarDarken.on) {
        CALayer *dim = [CALayer layer];
        dim.backgroundColor = [NSColor colorWithWhite:0 alpha:0.3].CGColor;
        [layers addObject:dim];
    }
    for (CALayer *layer in layers) {
        layer.frame = shade.bounds;
        layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
        [shade.layer addSublayer:layer];
    }
    [overlay.shade removeFromSuperview];
    [overlay addSubview:shade positioned:NSWindowBelow relativeTo:overlay.panel];
    overlay.shade = shade;
}

static NSTextView *DPBarText(DPCommandBarOverlay *overlay) {
    return (NSTextView *)DPFindView(overlay.panel, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
}

// The toolbar options that keep it on a new tab page check for the page when its pane lays out.
static void DPHidePage(NSView *page, BOOL hidden) {
    page.hidden = hidden;
    for (NSView *view = page.superview; view; view = view.superview)
        if (DPIsKind(view, DPDiaContentPane)) view.needsLayout = YES;
}

static void DPFocusBar(DPCommandBarOverlay *overlay) {
    NSTextView *text = DPBarText(overlay);
    if (text && overlay.host.firstResponder != text) [overlay.host makeFirstResponder:text];
}

// Puts the bar back in its new tab page and takes the overlay away. Returns the new tab, still open.
static id DPDismissCommandBar(DPCommandBarOverlay *overlay) {
    [overlay.watch invalidate];
    if (overlay.keyMonitor) [NSEvent removeMonitor:overlay.keyMonitor];
    overlay.keyMonitor = nil;
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
    id tab = DPDismissCommandBar(overlay);
    if (tab) DPCloseTab(tab);
}

// Picking something loads it in the new tab where it waits, so the tab moving off the new tab page means it was used.
static void DPWatchNewTab(DPCommandBarOverlay *overlay) {
    NSWindow *window = overlay.host;
    NSView *frame = window.contentView.superview;
    if (!window) return (void)DPDismissCommandBar(overlay);
    // Dia rebuilds a window's frame view as it restores it at launch.
    if (overlay.superview != frame) {
        overlay.frame = frame.bounds;
        [frame addSubview:overlay positioned:NSWindowAbove relativeTo:nil];
    }
    NSString *tabID = [overlay.openedTab valueForKey:@"tabId"];
    id tab = DPScriptTab(window, tabID);
    if (!tab) return (void)DPDismissCommandBar(overlay);
    NSString *url = [tab valueForKey:@"URL"];
    // A chat starts in the tab without loading a page, and Dia empties the bar once it has taken what was typed.
    BOOL taken = overlay.picked && !DPBarText(overlay).string.length;
    if (!taken && (url == overlay.startURL || [url isEqual:overlay.startURL])) return;
    DPDismissCommandBar(overlay);
    DPFocusTab(tab);
}

// Checks often for a moment after something in the bar is picked, so the new tab comes forward at once.
static void DPWatchSoon(DPCommandBarOverlay *overlay, int checks) {
    if (!checks || !overlay.host) return;
    __weak DPCommandBarOverlay *weak = overlay;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (!weak.host) return;
        DPWatchNewTab(weak);
        DPWatchSoon(weak, checks - 1);
    });
}

static void DPPresentCommandBar(NSView *page) {
    NSWindow *window = page.window;
    NSView *frame = window.contentView.superview, *panel = DPPanelIn(page);
    id scripted = DPScriptWindow(window), openedTab = [scripted valueForKey:@"activeTab"];
    if (!DPCommandBar.on || !panel || !frame || !openedTab || DPGet(page, &DPOverlayKey)) return;
    NSString *openedID = [openedTab valueForKey:@"tabId"];
    NSArray *recent = DPGet(window, &DPRecentKey);
    NSString *returnID = [recent.lastObject isEqual:openedID] ? (recent.count > 1 ? recent.firstObject : nil) : recent.lastObject;

    DPCommandBarOverlay *overlay = [[DPCommandBarOverlay alloc] initWithFrame:frame.bounds];
    overlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    overlay.page = page;
    overlay.panel = panel;
    overlay.openedTab = openedTab;
    overlay.host = window;
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
    __weak DPCommandBarOverlay *weak = overlay;
    overlay.keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown | NSEventMaskLeftMouseUp handler:^NSEvent *(NSEvent *event) {
        DPCommandBarOverlay *strong = weak;
        if (!strong || event.window != strong.host) return event;
        if (event.type == NSEventTypeLeftMouseUp || event.keyCode == 36 || event.keyCode == 76) {
            strong.picked = strong.picked || DPBarText(strong).string.length > 0;
            DPWatchSoon(strong, 60);
            return event;
        }
        BOOL close = (event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagCommand
                     && [event.charactersIgnoringModifiers isEqualToString:@"w"];
        if (event.keyCode != 53 && !close) return event;
        // Escape first closes what the bar opened over it, like its @ menu.
        NSRect bar = [strong.host convertRectToScreen:[strong.panel convertRect:strong.panel.bounds toView:nil]];
        for (NSWindow *child in strong.host.childWindows)
            if (event.keyCode == 53 && child.visible && NSIntersectsRect(child.frame, bar)) return event;
        DPCancelCommandBar(strong);
        return nil;
    }];
    overlay.watch = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        if (weak) DPWatchNewTab(weak); else [timer invalidate];
    }];
    // Dia is still switching to the new tab; going back has to wait for it to finish.
    if (overlay.returnTab)
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weak.superview) return;
            DPFocusTab(weak.returnTab);
            dispatch_async(dispatch_get_main_queue(), ^{ if (weak.superview) DPFocusBar(weak); });
        });
}

#pragma mark Hooks

// Dia keeps setting the bar's frame for where it sat in the new tab page; the size is Dia's, the place is ours.
static void DPPanel_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    if ([self.superview isKindOfClass:DPCommandBarOverlay.class]) frame = [(DPCommandBarOverlay *)self.superview frameForPanelSize:frame.size];
    DPCallOriginal(DPPanel_setFrame, self, frame);
}

static DPCommandBarOverlay *DPOverlayAbove(NSView *view) {
    while (view && ![view isKindOfClass:DPCommandBarOverlay.class]) view = view.superview;
    return (DPCommandBarOverlay *)view;
}

// The new tab page sizes the bar to fit its suggestions, and it's gone once its tab is behind, so the bar is sized
// here the way it was: its height closed, plus the suggestions and the 8 points Dia leaves under them. The views
// between the bar and its suggestions fill it, and grow with it so the bar lays its suggestions and toolbar out again.
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


// "Add tabs or files" only opens its menu for the new tab page the bar came from, which is gone once the page you were
// on is back. Typing @ opens the same menu from the bar itself, so the button types one.
static void DPCapability_mouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    DPCommandBarOverlay *overlay = DPOverlayAbove(self);
    if (!overlay.returnTab) return DPCallOriginal(DPCapability_mouseDown, self, event);
    DPFocusBar(overlay);
    [DPBarText(overlay) insertText:@"@" replacementRange:DPBarText(overlay).selectedRange];
}

static void DPContentPane_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPContentPane_viewDidMoveToWindow, self);
    if (self.window) DPNoteActiveTab(self.window);
}

static void DPNewTabPage_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNewTabPage_viewDidMoveToWindow, self);
    if (!self.window) return;
    DPNoteActiveTab(self.window);
    if (!DPCommandBar.on) return;
    // Brought forward while its bar is open, by a shortcut or the tab switcher, the new tab gets a fresh new tab page;
    // the bar already open stays, and the page you were on stays in front.
    DPCommandBarOverlay *overlay = DPGet(self.window, &DPOverlayKey);
    if (overlay && [DPActiveTabID(self.window) isEqual:[overlay.openedTab valueForKey:@"tabId"]]) {
        if (overlay.returnTab) dispatch_async(dispatch_get_main_queue(), ^{ if (overlay.host) DPFocusTab(overlay.returnTab); });
        return;
    }
    if (overlay) DPCancelCommandBar(overlay);
    // The bar lays itself out against the new tab page once that's in the window, so it's lifted after.
    __weak NSView *page = self;
    dispatch_async(dispatch_get_main_queue(), ^{ if (page.window) DPPresentCommandBar(page); });
}

static void DPApplyCommandBar(DPPatch *patch) {
    for (NSWindow *window in NSApp.windows) {
        DPCommandBarOverlay *overlay = DPGet(window, &DPOverlayKey);
        if (!overlay) continue;
        if (DPCommandBar.on) DPShowShade(overlay);
        else {
            id tab = DPDismissCommandBar(overlay);
            if (overlay.returnTab && tab) DPFocusTab(tab);
        }
    }
    if (DPCommandBar.on)
        for (NSView *page in DPFindViews(DPDiaNewTabPage)) DPPresentCommandBar(page);
}

static NSString *DPVerifyCommandBar(DPPatch *patch) {
    for (NSView *page in DPFindViews(DPDiaNewTabPage)) {
        DPCommandBarOverlay *overlay = DPGet(page, &DPOverlayKey);
        if (DPCommandBar.on && !overlay) return @"a new tab page shows without the bar over it";
        if (overlay && overlay.panel.superview != overlay) return @"the bar isn't on the overlay";
    }
    for (NSWindow *window in NSApp.windows)
        if (!DPCommandBar.on && DPGet(window, &DPOverlayKey)) return @"the bar is still open";
    return nil;
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

@interface DPCommandBarHeightRow : NSStackView
@property NSTextField *value;
@end

@implementation DPCommandBarHeightRow
- (void)slide:(NSSlider *)slider {
    [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] setDouble:slider.doubleValue forKey:@"commandBarHeight"];
    self.value.stringValue = [NSString stringWithFormat:@"%.0f%%", slider.doubleValue * 100];
    for (NSWindow *window in NSApp.windows) ((NSView *)DPGet(window, &DPOverlayKey)).needsLayout = YES;
}
@end

static NSView *DPCommandBarDebug(void) {
    NSSlider *slider = [NSSlider sliderWithValue:DPBarHeight() minValue:0 maxValue:0.5 target:nil action:@selector(slide:)];
    slider.controlSize = NSControlSizeSmall;
    [slider.widthAnchor constraintEqualToConstant:180].active = YES;
    NSTextField *value = [NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%", DPBarHeight() * 100]];
    value.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    DPCommandBarHeightRow *row = [DPCommandBarHeightRow stackViewWithViews:@[[NSTextField labelWithString:@"Room above the bar in macOS center"], slider, value]];
    row.value = value;
    slider.target = row;
    return row;
}

static void DPInstallCommandBar(void) {
    DPHook(DPDiaContentPane, @selector(viewDidMoveToWindow), (IMP)DPContentPane_viewDidMoveToWindow);
    DPHook(DPDiaNewTabPage, @selector(viewDidMoveToWindow), (IMP)DPNewTabPage_viewDidMoveToWindow);
    DPHook(DPDiaAssistantPanel, @selector(setFrame:), (IMP)DPPanel_setFrame);
    DPHook(DPDiaCommandBarSuggestions, @selector(invalidateIntrinsicContentSize), (IMP)DPSuggestions_invalidateIntrinsicContentSize);
    DPHook(DPDiaCapabilityButton, @selector(mouseDown:), (IMP)DPCapability_mouseDown);
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
    .debug = DPCommandBarDebug,
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
