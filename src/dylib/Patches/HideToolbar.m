#import "../DiaPatches.h"

static NSHashTable<NSView *> *DPPanes;
static char DPRequestedFrameKey, DPAssignedFrameKey, DPFillsKey;

static NSRect DPLaidOutFrame(NSView *view) {
    NSValue *assigned = objc_getAssociatedObject(view, &DPAssignedFrameKey);
    if (assigned && NSEqualRects(assigned.rectValue, view.frame))
        return [objc_getAssociatedObject(view, &DPRequestedFrameKey) rectValue];
    return view.frame;
}

static void DPAssignFrame(NSView *view, NSRect laidOut, NSRect frame) {
    objc_setAssociatedObject(view, &DPRequestedFrameKey, [NSValue valueWithRect:laidOut], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &DPAssignedFrameKey, [NSValue valueWithRect:frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.frame = frame;
}

static Class DPToolbarClass(void) {
    static Class cls;
    return cls = cls ?: NSClassFromString(@"_TtC13NavigationBar17NavigationBarView");
}

// The bar stays in Dia's layout: hiding it makes Dia reflow in ways it won't undo.
static NSView *DPToolbar_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    return DPHideToolbar.on ? nil : DPCallOriginal(NSView *(*)(id, SEL, NSPoint), self, _cmd, point);
}

static void DPApplyToolbar(NSView *pane) {
    NSView *bar = nil;
    for (NSView *sub in pane.subviews) if ([sub isKindOfClass:DPToolbarClass()]) { bar = sub; break; }
    if (!bar) return;

    CGFloat progress = DPHideToolbar.progress;
    bar.alphaValue = 1 - progress;
    NSView *lowest = pane.subviews.firstObject;
    if (progress > 0 && lowest != bar) [pane addSubview:bar positioned:NSWindowBelow relativeTo:lowest];
    else if (progress == 0 && lowest == bar) [pane addSubview:bar positioned:NSWindowAbove relativeTo:nil];

    BOOL flipped = pane.isFlipped;
    CGFloat (^top)(NSRect) = ^CGFloat(NSRect r) { return flipped ? NSMinY(r) : NSHeight(pane.bounds) - NSMaxY(r); };
    CGFloat (^bottom)(NSRect) = ^CGFloat(NSRect r) { return flipped ? NSMaxY(r) : NSHeight(pane.bounds) - NSMinY(r); };
    CGFloat shift = NSHeight(bar.frame) * progress, edge = bottom(bar.frame);
    NSMutableArray<NSView *> *stack = [NSMutableArray new];
    for (NSView *sub in pane.subviews) if (sub != bar) [stack addObject:sub];
    [stack sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        return [@(top(DPLaidOutFrame(a))) compare:@(top(DPLaidOutFrame(b)))];
    }];
    for (NSView *view in stack) {
        NSRect laidOut = DPLaidOutFrame(view);
        if (fabs(top(laidOut) - edge) > 0.5) continue;
        BOOL reachesBottom = fabs(bottom(laidOut) - NSHeight(pane.bounds)) < 0.5;
        if (!reachesBottom) edge = bottom(laidOut);
        NSRect frame = laidOut;
        if (reachesBottom) frame.size.height += shift;
        if (flipped) frame.origin.y -= shift;
        else if (!reachesBottom) frame.origin.y += shift;
        DPAssignFrame(view, laidOut, frame);
        // Dia sizes the web view once instead of autoresizing it.
        for (NSView *child in view.subviews) {
            if (!objc_getAssociatedObject(child, &DPFillsKey)) {
                if (!NSEqualRects(child.frame, (NSRect){NSZeroPoint, laidOut.size})) continue;
                objc_setAssociatedObject(child, &DPFillsKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            child.frame = view.bounds;
        }
    }
}

static void DPPane_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    [DPPanes addObject:self];
    DPApplyToolbar(self);
}

static void DPRelayoutPanes(void) {
    for (NSView *pane in DPPanes) {
        pane.needsLayout = YES;
        [pane layoutSubtreeIfNeeded];
    }
}

static void DPInstallHideToolbar(void) {
    DPPanes = [NSHashTable weakObjectsHashTable];
    DPHook(NSClassFromString(@"_TtC11ContentPane15ContentPaneView"), @selector(layout), (IMP)DPPane_layout);
    DPHook(DPToolbarClass(), @selector(hitTest:), (IMP)DPToolbar_hitTest);
}

static NSColor *DPGray(void) { return NSColor.systemGrayColor; }

DPPatch DPHideToolbar = {
    .key = @"hideToolbar",
    .title = @"Hide toolbar",
    .detail = @"Remove the bar with the address, navigation buttons and extensions. Experimental.",
    .symbol = @"menubar.rectangle",
    .tint = DPGray,
    .install = DPInstallHideToolbar,
    .relayout = DPRelayoutPanes,
};
