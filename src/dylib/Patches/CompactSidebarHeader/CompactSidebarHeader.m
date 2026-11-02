#import "StdPatch/StdPatch.h"

extern DPPatch DPCompactSidebarHeader;
static const CGFloat DPHeaderTrim = 10;
static NSHashTable<NSView *> *DPSidebars;
static char DPHeaderFrameKey;

static NSRect DPLaidOutHeader(NSView *header) {
    return [DPDiaValue(header, &DPHeaderFrameKey, @(header.frame)) rectValue];
}

// The sidebar header's buttons keep their place and the pinned tabs move up into the empty space under them.
static void DPCompactHeader(NSView *sidebar) {
    NSView *header = DPSubview(sidebar, DPDiaSidebarHeader);
    if (!header) return;
    NSRect laidOut = DPLaidOutHeader(header), frame = laidOut;
    if (DPCompactSidebarHeader.on) frame.size.height = MAX(0, NSHeight(laidOut) - DPHeaderTrim);
    DPOverride(header, &DPHeaderFrameKey, @(laidOut), @(frame));
    header.frame = frame;
    // The view under the header keeps its bottom edge, so whatever follows it stays put.
    for (NSView *sub in sidebar.subviews) {
        if (sub == header) continue;
        CGFloat top = NSMinY(sub.frame);
        if (fabs(top - NSMaxY(laidOut)) > 0.5 && fabs(top - NSMaxY(laidOut) + DPHeaderTrim) > 0.5) continue;
        sub.frame = NSMakeRect(NSMinX(sub.frame), NSMaxY(frame), NSWidth(sub.frame), NSMaxY(sub.frame) - NSMaxY(frame));
    }
}

static void DPSidebar_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPSidebar_viewDidLayout, self);
    [DPSidebars addObject:self.view];
    if (self.view.isFlipped) DPCompactHeader(self.view);
}

static void DPInstallCompactSidebarHeader(void) {
    DPSidebars = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPSidebar_viewDidLayout);
}

static void DPApplyCompactSidebarHeader(DPPatch *patch) { DPRelayoutViews(DPSidebars); }

// A sidebar that isn't open passes: with tabs at the top there's no header.
static NSString *DPVerifyCompactSidebarHeader(DPPatch *patch) {
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        if (header.hiddenOrHasHiddenAncestor || !header.superview.isFlipped) continue;
        CGFloat trimmed = NSHeight(DPLaidOutHeader(header)) - NSHeight(header.frame);
        if (fabs(trimmed - (patch->on ? DPHeaderTrim : 0)) > 0.5) return patch->on ? @"header is full height" : @"header is still trimmed";
    }
    return nil;
}

DP_PATCH(DPCompactSidebarHeader) {
    .key = @"compactSidebarHeader",
    .order = 76,
    .section = @"Sidebar & Tab Bar",
    .title = @"Compact sidebar header",
    .detail = @"Move the pinned tabs up into the empty space under the window buttons.",
    .symbol = @"rectangle.compress.vertical",
    .tint = @"systemMintColor",
    .classes = DPClasses(DPDiaSidebarController, DPDiaSidebarHeader),
    .install = DPInstallCompactSidebarHeader,
    .apply = DPApplyCompactSidebarHeader,
    .verify = DPVerifyCompactSidebarHeader,
};
