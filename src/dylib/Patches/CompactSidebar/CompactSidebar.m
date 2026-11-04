#import "CompactSidebar.h"

static void DPInstallCompactSidebar(void) {
    DPInstallCompactFrames();
    DPInstallCompactHeader();
    DPInstallCompactPage();
    DPInstallCompactRows();
    DPInstallCompactList();
    DPInstallCompactFolders();
    DPInstallCompactChrome();
    DPInstallCompactShortcut();
    DPInstallCompactReveal();
    DPInstallCompactBackdrop();
}

static void DPApplyCompactSidebar(DPPatch *patch) {
    DPMatchAutoHide(patch->on);
    DPRelayoutCompactSidebar();
}

// Only a sidebar that Auto-Hide Tabs hides changes; one docked beside the page, or tabs at the top, pass.
static NSString *DPVerifyCompactSidebar(DPPatch *patch) {
    NSMutableArray<NSView *> *hosts = [NSMutableArray new];
    for (NSView *root in DPFindViews(DPDiaSidebarRoot)) {
        NSView *host = DPHostIn(root.window);
        if (host && ![hosts containsObject:host]) [hosts addObject:host];
    }
    for (NSView *host in hosts) {
        NSWindow *window = host.window;
        if (!window.isVisible || DPStripSliding(window) || NSMaxX(DPDiaHostFrame(host)) > 0) continue;
        BOOL showing = !host.hidden && NSMaxX(host.frame) > 0;
        if (!patch->on || DPStripHiddenIn(window)) {
            if (showing) return patch->on ? @"strip shows after ⌘S hid it" : @"strip still shows";
            continue;
        }
        if (!showing) return @"no strip while tabs auto-hide";
        if (DPStripExpanded(host)) continue;
        CGFloat width = DPStripWidth + DPRevealRoom(window) * DPLightsReveal(window);
        if (NSMinX(host.frame) != 0 || NSWidth(host.frame) > width + 0.5) return @"strip isn't at the window's edge";
        for (NSView *pane in DPFindViews(DPDiaContentPane)) {
            if (pane.window != window || pane.hiddenOrHasHiddenAncestor) continue;
            if (NSMinX([pane convertRect:pane.bounds toView:nil]) < DPStripRight(window) - 0.5) return @"page runs under the strip";
        }
        CGFloat lights = DPLightsRight(window);
        for (NSView *bar in DPFindViews(DPDiaToolbar)) {
            if (bar.window != window || bar.hiddenOrHasHiddenAncestor || lights == 0) continue;
            NSView *field = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); });
            for (NSView *item in field.superview.subviews) {
                if (item.hidden || NSWidth(item.frame) == 0) continue;
                NSRect r = [item convertRect:item.bounds toView:nil];
                if (NSMinX(r) < lights && NSMaxX(r) > 0) return @"toolbar buttons under the window buttons";
            }
        }
    }
    return nil;
}

DP_PATCH(DPCompactSidebar) {
    .key = @"compactSidebar",
    .order = 77,
    .title = @"Compact Sidebar",
    .detail = @"Shrink the sidebar to a strip of icons under a full-width toolbar, like Zen. Point at the strip to open the whole sidebar over the page; ⌘S hides it completely.",
    .symbol = @"sidebar.squares.left sidebar.left",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaWindowController, DPDiaFloatingSidebar, DPDiaSidebarRoot, DPDiaSidebarController, DPDiaSidebarHeader,
                         DPDiaTrafficLights, DPDiaContentContainer, DPDiaContentPane, DPDiaToolbar, DPDiaAddressField, DPDiaCallbackMenuItem, DPDiaTabListLayout),
    .install = DPInstallCompactSidebar,
    .apply = DPApplyCompactSidebar,
    .verify = DPVerifyCompactSidebar,
};
