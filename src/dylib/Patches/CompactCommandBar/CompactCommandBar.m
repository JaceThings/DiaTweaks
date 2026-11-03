#import "CompactCommandBar.h"

NSView *DPCommandBarPart(NSView *commandBar, const char *className) {
    return DPFindView(commandBar, ^BOOL(NSView *view) { return DPIsKind(view, className); });
}

BOOL DPChatLocked(NSView *view) {
    return DPFindView(view, ^BOOL(NSView *v) { return [v.accessibilityLabel hasSuffix:@"only available when you have chat usage"]; }) != nil;
}

// Dia labels the buttons a moment after a command bar first shows, so until then it goes by the last one it labeled.
static NSString *const DPChatLockedKey = @"commandBarChatLocked";

static NSUserDefaults *DPCommandBarDefaults(void) {
    static NSUserDefaults *defaults;
    if (!defaults) defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    return defaults;
}

void DPRememberChatLocked(BOOL locked) {
    if ([DPCommandBarDefaults() boolForKey:DPChatLockedKey] != locked) [DPCommandBarDefaults() setBool:locked forKey:DPChatLockedKey];
}

NSView *DPCompactToolbar(NSView *commandBar) {
    NSView *toolbar = commandBar ? DPCommandBarPart(commandBar, DPDiaCommandBarToolbar) : nil;
    BOOL locked = toolbar && (DPCompactWithChat.on || DPChatLocked(toolbar) || [DPCommandBarDefaults() boolForKey:DPChatLockedKey]);
    return DPCompactCommandBar.on && locked ? toolbar : nil;
}

NSView *DPGoButton(NSView *toolbar) {
    NSStackView *stack = toolbar.subviews.firstObject;
    return [stack isKindOfClass:NSStackView.class] ? stack.views.lastObject : nil;
}

void DPApplyCompactCommandBar(DPPatch *patch) {
    for (NSView *commandBar in DPFindViews(DPDiaCommandBar)) commandBar.needsLayout = YES;
    DPResizeNewTabPanels();
    DPResizePopovers();
}

// A command bar that isn't open passes, as does one with chat usage, which keeps its bottom row unless asked not to.
static NSString *DPVerifyCompactCommandBar(DPPatch *patch) {
    for (NSView *commandBar in DPFindViews(DPDiaCommandBar)) {
        NSView *toolbar = DPCommandBarPart(commandBar, DPDiaCommandBarToolbar), *go = DPGoButton(toolbar);
        NSView *input = DPCommandBarPart(commandBar, DPDiaCommandBarInput);
        if (!go || !input || !(DPChatLocked(toolbar) || DPCompactWithChat.on)) continue;
        NSRect goFrame = [go convertRect:go.bounds toView:input.superview];
        BOOL beside = NSMinY(goFrame) < NSMaxY(input.frame) && NSMaxY(goFrame) > NSMinY(input.frame);
        if (beside != patch->on) return patch->on ? @"Go is still under the input" : @"Go is still beside the input";
        // The new tab page's panel drops the empty row; the command bar inside keeps its height.
        NSView *panel = commandBar.superview.superview;
        if (DPIsKind(panel, DPDiaAssistantPanel) && DPIsKind(panel.superview.superview, DPDiaNewTabPage)
            && (NSHeight(panel.frame) < NSHeight(commandBar.frame) - 0.5) != patch->on)
            return patch->on ? @"new tab page keeps the empty row" : @"new tab page is still trimmed";
    }
    return nil;
}

DP_PATCH(DPCompactCommandBar) {
    .key = @"compactCommandBar",
    .order = 97,
    .section = @"Command Bar",
    .title = @"Compact command bar",
    .detail = @"Fit the command bar on one line when adding tabs, files and dictation need chat usage.",
    .symbol = @"rectangle.and.text.magnifyingglass",
    .tint = @"systemCyanColor",
    .classes = DPClasses(DPDiaPopover, DPDiaAssistantPanel, DPDiaNewTabPage, DPDiaCommandBar, DPDiaCommandBarInput, DPDiaCommandBarText, DPDiaCommandBarSuggestions, DPDiaCommandBarToolbar, DPDiaCommandBarButton),
    .install = DPInstallCommandBarLayout,
    .apply = DPApplyCompactCommandBar,
    .verify = DPVerifyCompactCommandBar,
};
