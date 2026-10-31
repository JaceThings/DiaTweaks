#import "SidebarToolbar.h"

static char DPHiddenKey, DPShiftKey;

NSView *DPSidebarHeader(NSView *sidebar) {
    return DPSubview(sidebar, DPDiaSidebarHeader);
}

NSRect DPHeaderRow(NSView *sidebar) {
    NSView *header = DPSidebarHeader(sidebar);
    NSRect row = NSZeroRect;
    for (NSView *sub in header.subviews) row = NSUnionRect(row, sub.frame);
    return header ? [sidebar convertRect:row fromView:header] : NSMakeRect(0, 0, NSWidth(sidebar.bounds), DPDockRowHeight);
}

NSView *DPLights(NSView *header) {
    return DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaWindowButtons); });
}

// Below the header's controls, so the traffic lights have as much space under them as above.
CGFloat DPHeaderGap(NSView *sidebar) {
    NSView *lights = DPLights(DPSidebarHeader(sidebar));
    NSView *light = DPFindView(lights, ^BOOL(NSView *v) { return v != lights && NSWidth(v.bounds) > 0 && NSWidth(v.bounds) <= 16; });
    if (!light) return 0;
    NSRect circle = [sidebar convertRect:light.bounds fromView:light], row = DPHeaderRow(sidebar);
    CGFloat (^top)(NSRect) = ^CGFloat(NSRect r) { return sidebar.isFlipped ? NSMinY(r) : NSHeight(sidebar.bounds) - NSMaxY(r); };
    CGFloat below = top(row) + NSHeight(row) - top(circle) - NSHeight(circle);
    return MAX(0, round(top(circle) - below));
}

// From the top of the header's controls: their row, a row for extensions if any, then the address.
NSRect DPDockFrame(NSView *sidebar, NSView *bar) {
    NSRect row = DPHeaderRow(sidebar);
    CGFloat extras = bar && DPBarItems(bar, NO).count ? DPDockRowHeight : 0;
    return NSMakeRect(0, NSMinY(row), NSWidth(sidebar.bounds), NSHeight(row) + DPHeaderGap(sidebar) + extras + DPDockFieldHeight + DPDockBottom);
}

void DPSetHiddenByUs(NSView *view, BOOL hidden) {
    if (hidden && !view.hidden) {
        view.hidden = YES;
        DPSet(view, &DPHiddenKey, @YES);
    } else if (!hidden && DPGet(view, &DPHiddenKey)) {
        view.hidden = NO;
        DPSet(view, &DPHiddenKey, nil);
    }
}

// Room for the bar between the sidebar's header and its tabs.
static void DPSidebar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebar_layout, self);
    [DPSidebars addObject:self];
    DPUpdateDock(self.window);
    NSView *bar = DPSubview(self, DPDiaToolbar), *split = DPSubview(self, class_getName(DPSplitAddress.class));
    NSView *header = DPSidebarHeader(self);
    if (!header) return;
    NSView *profile = DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaProfileButton); }).superview;
    if (profile) DPSetHiddenByUs(profile, DPDocking());
    DPArrangeFooter(self, header, DPDocking());
    NSRect dock = bar || split ? DPDockFrame(self, bar) : NSZeroRect;
    if (bar) DPSetBarFrame(bar, dock);
    if (split) split.frame = dock;
    CGFloat shift = bar || split ? NSMaxY(dock) - NSMaxY(header.frame) : 0;
    for (NSView *sub in self.subviews) {
        NSRect laidOut = [DPDiaValue(sub, &DPShiftKey, @(sub.frame)) rectValue];
        if (sub == bar || sub == split || fabs(NSMinY(laidOut) - NSMaxY(header.frame)) > 0.5) continue;
        NSRect frame = laidOut;
        frame.origin.y += shift, frame.size.height -= shift;
        DPOverride(sub, &DPShiftKey, @(laidOut), @(frame));
        if (!NSEqualRects(sub.frame, frame)) sub.frame = frame;
    }
}

// With tabs at the top, Dia takes the sidebar out of the window, and the docked bar would go with it.
static void DPSidebar_viewWillMoveToWindow(NSView *self, SEL _cmd, NSWindow *window) {
    if (window != self.window) DPUndockAll(self);
    DPCallOriginal(DPSidebar_viewWillMoveToWindow, self, window);
}

// The sidebar's view is a private class whose name carries a build hash, so it's found as the header's superview.
static void DPHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_layout, self);
    static Class sidebarClass;
    NSView *sidebar = self.superview;
    if (sidebarClass || ![NSStringFromClass(sidebar.class) containsString:@"Sidebar"]) return;
    sidebarClass = sidebar.class;
    DPHookClass(sidebarClass, @selector(layout), (IMP)DPSidebar_layout);
    DPHookClass(sidebarClass, @selector(viewWillMoveToWindow:), (IMP)DPSidebar_viewWillMoveToWindow);
    sidebar.needsLayout = YES;
}

void DPInstallSidebar(void) {
    DPHook(DPDiaSidebarHeader, @selector(layout), (IMP)DPHeader_layout);
}
