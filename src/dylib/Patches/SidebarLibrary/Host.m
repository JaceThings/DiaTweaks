#import "Library.h"
void DPLibraryBindHost(NSView *,DPLibraryController *,BOOL);
void DPLibraryRestoreHost(NSView *,DPLibraryController *);
void DPLibraryUpdateHost(NSView *,DPLibraryController *);
@interface DPLibraryHorizontalHost : NSView @end
@implementation DPLibraryHorizontalHost
- (BOOL)isFlipped { return YES; }
@end
static void DPLibraryRelayoutPage(NSView *page) {
    if (!page) return;
    page.needsLayout = YES;
    DPFindView(page,^BOOL(NSView *view) { if (DPIsKind(view,DPDiaContentPane)) view.needsLayout = YES; return NO; });
    [page layoutSubtreeIfNeeded];
}
BOOL DPLibraryMount(DPLibraryController *controller) {
    NSView *content = controller.window.contentView;
    NSView *header = DPFindView(content,^BOOL(NSView *v) { return DPIsKind(v,DPDiaSidebarHeader) && !v.hiddenOrHasHiddenAncestor; });
    NSView *page = DPFindView(content,^BOOL(NSView *v) { return DPIsKind(v,DPDiaContentContainer) && !v.hiddenOrHasHiddenAncestor; });
    if (!page) return NO;
    NSView *sidebar = header.superview;
    if (NSWidth(sidebar.frame)<80 || NSMaxX(sidebar.frame)<=0) { sidebar = nil; header = nil; }
    // Horizontal tabs and an auto-hidden sidebar have no visible native host.
    // Keep Library in the browser's content hierarchy in either case.
    if (!sidebar) {
        NSRect frame = page.frame; frame.size.width = 0;
        sidebar = [[DPLibraryHorizontalHost alloc] initWithFrame:frame];
        sidebar.autoresizingMask = NSViewHeightSizable;
        [page.superview addSubview:sidebar positioned:NSWindowAbove relativeTo:page];
        controller.ownsHost = YES;
    }
    if (!sidebar || !sidebar.isFlipped || [page isDescendantOf:sidebar]) return NO;
    controller.sidebarHost = sidebar; controller.pageHost = page;
    controller.expanded = YES; controller.expansion = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? 1 : 0;
    DPLibraryBindHost(controller.sidebarHost,controller,YES);
    DPLibraryBindHost(page,controller,NO);
    controller.view.hidden = NO;
    [controller.sidebarHost addSubview:controller.view positioned:header ? NSWindowBelow : NSWindowAbove relativeTo:header];
    [controller.sidebarHost layoutSubtreeIfNeeded]; [page layoutSubtreeIfNeeded];
    return YES;
}
void DPLibraryUnmount(DPLibraryController *controller) {
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    // Detach the outgoing content before restoring its origin or the native
    // host's layer ownership. Neither restoration may paint Library over tabs.
    controller.view.hidden = YES;
    [controller.view removeFromSuperview];
    controller.expanded = NO;
    DPLibraryUncoverTabs(controller);
    for (NSView *view in @[controller.sidebarHost ?: NSView.new,controller.pageHost ?: NSView.new]) {
        DPLibraryRestoreHost(view,controller);
    }
    DPLibraryUpdateBackdrop(controller);
    DPLibraryEndInteractiveLayout(controller);
    if (controller.ownsHost) [controller.sidebarHost removeFromSuperview];
    DPLibraryRelayoutPage(controller.pageHost);
    controller.ownsHost = NO; controller.sidebarHost = nil; controller.pageHost = nil;
    [CATransaction commit];
}

void DPLibraryUpdateHosts(DPLibraryController *controller) {
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    for (NSView *view in @[controller.sidebarHost ?: NSView.new,controller.pageHost ?: NSView.new]) {
        DPLibraryUpdateHost(view,controller);
    }
    DPLibraryUpdateBackdrop(controller);
    // During the reveal, clip the existing page instead of recursively laying
    // out Chromium and every native toolbar at 60 Hz. Settle once at the end.
    [controller layout];
    if (controller.expansion == 0 || controller.expansion == 1) {
        [controller.sidebarHost setNeedsLayout:YES];
        [controller.sidebarHost layoutSubtreeIfNeeded];
        DPLibraryRelayoutPage(controller.pageHost);
    }
    [CATransaction commit];
}
