#import "HideToolbar.h"

// Back, forward and reload in the hidden toolbar, in that order, or nil if they aren't all there.
static NSArray<NSView *> *DPButtonsIn(NSView *bar) {
    NSView *reload = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaReloadIcon); }).superview;
    NSMutableArray<NSView *> *buttons = [NSMutableArray new];
    for (NSView *sub in reload.superview.subviews)
        if (DPIsKind(sub.subviews.firstObject, DPDiaChevronIcon)) [buttons addObject:sub];
    return reload && buttons.count == 2 ? [buttons arrayByAddingObject:reload] : nil;
}

static NSView *DPHeaderIn(NSWindow *window) {
    if (!window || DPTabsAtTop(window)) return nil;
    return DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaSidebarHeader); });
}

// With split panes, the buttons act on the one you're using.
static NSView *DPFocusedPane(NSWindow *window) {
    NSView *first = nil;
    NSResponder *responder = window.firstResponder;
    for (NSView *pane in DPPanes) {
        if (pane.window != window || pane.hiddenOrHasHiddenAncestor) continue;
        if ([responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:pane]) return pane;
        if (!first) first = pane;
    }
    return first;
}

// From the moment the toolbar starts to hide until anything shows it again.
static BOOL DPToolbarHidden(NSView *pane) {
    DPToolbarHover *hover = [DPToolbarHover forPane:pane];
    return DPNavigationInSidebar.on && DPHideToolbar.on && hover.bar && !hover.revealed && hover.progress == 0 &&
           !hover.inPlace && hover.inPlaceProgress == 0 && !DPToolbarHasPermissionRequest(hover);
}

void DPPlaceNavigationButtons(NSWindow *window) {
    NSView *header = DPHeaderIn(window), *focused = header ? DPFocusedPane(window) : nil;
    BOOL wanted = focused && DPToolbarHidden(focused);
    DPNavigationHolder *holder = [DPNavigationHolder inHeader:header create:wanted];
    if (holder && !holder.dia) {
        __weak DPNavigationHolder *weak = holder;
        holder.dia = ^NSArray<NSView *> *{ return DPButtonsIn(DPSubview(DPFocusedPane(weak.window), DPDiaToolbar)); };
    }
    [holder show:wanted];
}

static void DPHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_layout, self);
    DPPlaceNavigationButtons(self.window);
}

static void DPInstallNavigationInSidebar(void) { DPHook(DPDiaSidebarHeader, @selector(layout), (IMP)DPHeader_layout); }

static NSString *DPVerifyNavigationInSidebar(DPPatch *patch) {
    for (NSView *pane in DPFindViews(DPDiaContentPane)) {
        NSView *bar = DPSubview(pane, DPDiaToolbar);
        if (bar && !DPButtonsIn(bar)) return @"toolbar lost its navigation buttons";
    }
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        NSView *focused = DPFocusedPane(header.window);
        BOOL wanted = focused && DPToolbarHidden(focused) && !DPTabsAtTop(header.window);
        if (wanted != [DPNavigationHolder inHeader:header create:NO].wanted)
            return wanted ? @"navigation buttons aren't in the sidebar" : @"navigation buttons show with the toolbar";
    }
    return nil;
}

DP_PATCH(DPNavigationInSidebar) {
    .key = @"navigationInSidebar",
    .order = 44,
    .title = @"Move Back, Forward and Reload to Sidebar",
    .detail = @"Show the back, forward and reload buttons next to the profile name in the sidebar. When the sidebar is too narrow, they fold into one button with a menu.",
    .symbol = @"arrow.left.arrow.right",
    .tint = @"systemIndigoColor",
    .requires = @"hideToolbar",
    .section = @"While It’s Hidden",
    .classes = DPClasses(DPDiaToolbar, DPDiaSidebarHeader, DPDiaProfileButton, DPDiaReloadIcon, DPDiaChevronIcon),
    .install = DPInstallNavigationInSidebar,
    .apply = DPApplyRelayoutPanes,
    .verify = DPVerifyNavigationInSidebar,
};
