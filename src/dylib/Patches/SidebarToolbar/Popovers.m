#import "SidebarToolbar.h"

// Editing the docked address opens the command bar as wide as the field, which is too narrow in the sidebar.
// It also leaves room above its input to clear Dia's toolbar; over the docked address that only pushes it up
// over the traffic lights, so the room shrinks to its side padding and the popover moves down.
static const CGFloat DPPopoverWidth = 380, DPCommandBarTop = 16;
static CGFloat DPCommandBarInset;
static char DPRequestedFrameKey, DPAssignedFrameKey;

static BOOL DPPopoverOverAddress(NSView *popover, NSRect frame) {
    NSView *superview = popover.superview, *address = nil;
    for (NSView *sidebar in DPSidebars) {
        NSView *bar = popover.window && sidebar.window == popover.window ? DPSubview(sidebar, DPDiaToolbar) : nil;
        if (bar) address = DPBarAddress(bar);
    }
    // Closing, it shrinks back to the field (plus its 10pt shadow margins); that frame is left alone.
    return address && superview && NSWidth(frame) - 20 > NSWidth(address.frame) + 0.5
        && NSIntersectsRect([superview convertRect:frame toView:nil], [address convertRect:address.bounds toView:nil]);
}

static NSView *DPPopoverOf(NSView *view) {
    while (view && ![NSStringFromClass(view.class) containsString:@"DynamicPopover"]) view = view.superview;
    return view;
}

static void DPPopover_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPSet(self, &DPRequestedFrameKey, @(frame));
    if (DPPopoverOverAddress(self, frame)) {
        if (NSWidth(frame) < DPPopoverWidth) frame.size.width = MIN(DPPopoverWidth, NSMaxX(self.superview.bounds) - NSMinX(frame) - DPDockInset);
        CGFloat shift = DPCommandBarInset - DPCommandBarTop;
        if (shift > 0 && self.superview.isFlipped) frame.origin.y += shift, frame.size.height -= shift;
    }
    DPCallOriginal(DPPopover_setFrame, self, frame);
}

// The popover's view is a hashed private class, reached through its controller.
static void DPPopoverController_viewWillAppear(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPPopoverController_viewWillAppear, self);
    NSView *view = self.view;
    if (![NSStringFromClass(view.class) containsString:@"DynamicPopover"]) return;
    DPHookClass(view.class, @selector(setFrame:), (IMP)DPPopover_setFrame);
    view.frame = view.frame;
}

static void DPCommandBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPCommandBar_layout, self);
    NSView *content = self.subviews.firstObject, *input = DPSubview(content, DPDiaCommandBarInput), *popover = DPPopoverOf(self);
    if (!input || !popover || !content.isFlipped) return;
    // The popover's first frames arrive before the inset is known.
    if (NSMinY(input.frame) != DPCommandBarInset) {
        DPCommandBarInset = NSMinY(input.frame);
        NSValue *requested = DPGet(popover, &DPRequestedFrameKey);
        if (requested) popover.frame = requested.rectValue;
    }
    // The popover lost that room at its top; views Dia places from the top move up into it, those it
    // places from the bottom already moved with the bottom. A view moved before and not placed since is left.
    CGFloat shift = DPPopoverOverAddress(popover, popover.frame) ? MAX(0, DPCommandBarInset - DPCommandBarTop) : 0;
    for (NSView *sub in content.subviews) {
        NSValue *assigned = DPGet(sub, &DPAssignedFrameKey);
        if ((assigned && NSEqualRects(assigned.rectValue, sub.frame)) || NSMaxY(sub.frame) >= NSHeight(content.bounds) - 0.5) continue;
        NSRect frame = NSOffsetRect(sub.frame, 0, -shift);
        sub.frame = frame;
        DPSet(sub, &DPAssignedFrameKey, @(frame));
    }
}

void DPInstallPopovers(void) {
    DPHook(DPDiaPopoverController, @selector(viewWillAppear), (IMP)DPPopoverController_viewWillAppear);
    DPHook(DPDiaCommandBar, @selector(layout), (IMP)DPCommandBar_layout);
}
