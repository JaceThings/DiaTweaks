#import "HideToolbar.h"

// Dia confirms a copied URL in the address field, which is out of sight while the toolbar is hidden, so this shows the
// toolbar for a moment. It follows Dia's own menu items, so ⇧⌘C and ⌥⇧⌘C keep doing what Dia does.

// What Dia's address field says after each Copy URL item in the Edit menu.
static NSString *DPCopiedMessage(NSMenuItem *item) {
    if ([item.title isEqual:@"Copy URL"]) return @"Copied current URL";
    if ([item.title isEqual:@"Copy URL as Markdown"]) return @"Copied URL as Markdown";
    return nil;
}

// The pane with the focused page: Dia copies its URL.
static NSView *DPFocusedPane(void) {
    NSWindow *window = NSApp.keyWindow;
    NSResponder *responder = window.firstResponder;
    NSView *first = nil;
    for (NSView *pane in DPPanes) {
        if (pane.window != window || pane.hiddenOrHasHiddenAncestor) continue;
        if ([responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:pane]) return pane;
        first = first ?: pane;
    }
    return first;
}

static void DPCopiedURL(NSNotification *notification) {
    NSString *message = DPCopiedMessage(notification.userInfo[@"MenuItem"]);
    NSView *pane = message && DPHideToolbar.on ? DPFocusedPane() : nil;
    DPToolbarHover *hover = [DPToolbarHover forPane:pane];
    if (!hover || hover.inPlace) return;  // Dia's own message shows in the toolbar.
    if (DPPeekToolbarOnCopy.on) [hover peek];
}

static void DPInstallCopyURL(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidSendActionNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *notification) { DPCopiedURL(notification); }];
}

static void DPApplyPeekOnCopy(DPPatch *patch) {
    if (patch->on) return;
    for (NSView *pane in DPPanes) [[DPToolbarHover forPane:pane] endPeek];
}

static NSString *DPVerifyPeekOnCopy(DPPatch *patch) {
    for (NSView *pane in DPFindViews(DPDiaContentPane))
        if ([DPToolbarHover forPane:pane].peeking && !patch->on) return @"toolbar still peeking";
    return nil;
}

DP_PATCH(DPPeekToolbarOnCopy) {
    .key = @"peekToolbarOnCopy",
    .order = 41,
    .title = @"Show Toolbar When Copying URL",
    .detail = @"Show the toolbar for a moment after ⇧⌘C, so you see Dia's Copied message.",
    .symbol = @"link",
    .tint = @"systemIndigoColor",
    .requires = @"hideToolbar",
    .install = DPInstallCopyURL,
    .apply = DPApplyPeekOnCopy,
    .verify = DPVerifyPeekOnCopy,
};
