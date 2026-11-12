#import "Patches/PinnedTabCloseButton/PinnedTabs.h"

// Dia gives an open tab under a folded pinned folder a minus button that closes its page and keeps the tab. This gives
// every open pinned tab one. A click is sent as Dia's closeKeepingTab style, which does the same for any pinned tab.
// ⌘W on the tab you're on does what its minus does. An option of the close button, which already shows the button on
// pinned tabs outside a folder.

enum { DPDismiss = 2 };  // TabUI.TabCloseButtonStyle.

static NSImage *DPMinus;
static char DPDiaImageKey;

// The tab controller of an open pinned tab with one page, unless Dia already gives it a minus button.
static id DPMinusController(NSView *content) {
    NSView *tab = DPEnclosingTab(content);
    if (!tab || !DPIsOpenPinned(content) || [DPSwiftValue(tab, @"contentViews") count] != 1) return nil;
    id controller = DPViewModelDelegate(tab);
    uint8_t *style = DPIvar(controller, "requestedCloseButtonStyle");
    return style && *style != DPDismiss ? controller : nil;
}

static BOOL DPMinusOn(void) { return DPPinnedTabCloseButton.on && DPPinnedTabMinusButton.on; }

static NSButton *DPCloseButton(NSView *content) {
    void **button = DPIvar(content, "$__lazy_storage_$_closeButton");
    return button && *button ? (__bridge NSButton *)*button : nil;
}

static void DPContent_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPContent_layout, self);
    NSButton *button = DPCloseButton(self);
    NSImage *dia = DPDiaValue(button, &DPDiaImageKey, button.image);
    if (!dia) return;
    BOOL minus = DPMinusOn() && DPMinusController(self);
    if (minus) DPOverride(button, &DPDiaImageKey, dia, DPMinus);
    if (button.image != (minus ? DPMinus : dia)) button.image = minus ? DPMinus : dia;
}

// The button's icon decides, so a click does what it showed. Keeping the tab is the safe guess if the tab changed since.
static void DPContent_closeButtonClicked(NSView *self, SEL _cmd) {
    BOOL minus = DPMinusOn() && DPCloseButton(self).image == DPMinus;
    if (!(minus && DPClickKeepingTab(self, ^{ DPCallOriginal(DPContent_closeButtonClicked, self); })))
        DPCallOriginal(DPContent_closeButtonClicked, self);
}

#pragma mark ⌘W

// Dia's ⌘W removes a pinned tab outside a folder. On a tab with the minus it does what the minus does instead.

static NSView *DPEnclosing(NSView *view, const char *className) {
    while (view && !DPIsKind(view, className)) view = view.superview;
    return view;
}

// selectionStyle is "none" when unselected, nil on an unselected pinned tab, and above/below on the selection's neighbours.
static BOOL DPTabSelected(NSView *tab) {
    id state = DPSwiftValue(DPSwiftValue(DPSwiftValue(tab, @"viewModel"), @"stateSubject"), @"currentValue");
    NSString *style = [[DPSwiftValue(state, @"selectionStyle") description] lowercaseString];
    return style && ![style containsString:@"none"] && ![style containsString:@"above"] && ![style containsString:@"below"];
}

// The list keeps cells it isn't showing, hidden, so a hidden cell is skipped but a collapsed sidebar isn't.
static BOOL DPTabShown(NSView *tab) {
    for (NSView *view = tab; view && ![view isKindOfClass:NSCollectionView.class]; view = view.superview)
        if (view.hidden) return NO;
    return YES;
}

// The page row of the tab you're on, while ⌘W closes the whole tab: one page fills the window, and that page, the sidebar
// or the window has focus. Otherwise ⌘W closes something smaller, like one side of a split or the chat.
static NSView *DPFrontContent(NSWindow *window) {
    NSUInteger panes = 0;
    for (NSView *pane in DPFindViews(DPDiaContentPane)) panes += pane.window == window && !pane.hiddenOrHasHiddenAncestor;
    NSView *focus = [window.firstResponder isKindOfClass:NSView.class] ? (NSView *)window.firstResponder : nil;
    if (panes != 1 || (focus && !DPEnclosing(focus, DPDiaContentPane) && DPEnclosing(focus, DPDiaContentContainer))) return nil;
    for (NSView *content in DPFindViews(DPDiaTabContentView)) {
        NSView *tab = DPEnclosingTab(content);
        if (content.window == window && tab && DPTabShown(tab) && DPTabSelected(tab)) return content;
    }
    return nil;
}

// File > Close Tab.
static void DPWindow_closeFocusedContent(NSWindowController *self, SEL _cmd, id sender) {
    NSView *content = DPMinusOn() ? DPFrontContent(self.window) : nil;
    if (!(content && DPMinusController(content) && DPCloseKeepingTab(content))) DPCallOriginal(DPWindow_closeFocusedContent, self, sender);
}

#pragma mark Patch

static void DPApplyPinnedTabMinusButton(DPPatch *patch) { DPRelayoutTabContents(); }

static NSString *DPVerifyPinnedTabMinusButton(DPPatch *patch) {
    for (NSView *content in DPFindViews(DPDiaTabContentView)) {
        id controller = DPViewModelDelegate(content);
        NSButton *button = DPCloseButton(content);
        if (!controller || !button || content.needsLayout) continue;
        if (!DPIvar(controller, "attributesController")) return @"can't tell which tabs have a page open";
        id attributes = DPAttributes(content);
        if (attributes && !(DPIvar(attributes, "activeURL") && DPIvar(attributes, "isInFavoritesOrPinnedContainer")))
            return @"can't tell which tabs have a page open";
        BOOL minus = button.image == DPMinus;
        if (DPMinusOn() && DPMinusController(content) && !minus) return @"open pinned tab has no minus button";
        if (!DPMinusOn() && minus) return @"tab keeps the minus button";
    }
    return nil;
}

static void DPInstallPinnedTabMinusButton(void) {
    DPMinus = [NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:@"Close"];
    DPHook(DPDiaTabContentView, @selector(layout), (IMP)DPContent_layout);
    DPHook(DPDiaTabContentView, NSSelectorFromString(@"closeButtonClicked"), (IMP)DPContent_closeButtonClicked);
    DPHook(DPDiaWindowController, NSSelectorFromString(@"closeFocusedContent:"), (IMP)DPWindow_closeFocusedContent);
}

DP_PATCH(DPPinnedTabMinusButton) {
    .key = @"pinnedTabMinusButton",
    .order = 86,
    .title = @"Minus Button on Open Pinned Tabs",
    .detail = @"Show a minus button instead on pinned tabs with a page open, in or out of a folder, as in Arc. It closes the page and keeps the tab pinned, and ⌘W does the same.",
    .symbol = @"minus.circle.fill",
    .tint = @"systemPinkColor",
    .requires = @"pinnedTabCloseButton",
    .classes = DPClasses(DPDiaTabView, DPDiaTabContentView, DPDiaTabPageAttributes),
    .install = DPInstallPinnedTabMinusButton,
    .apply = DPApplyPinnedTabMinusButton,
    .verify = DPVerifyPinnedTabMinusButton,
};
