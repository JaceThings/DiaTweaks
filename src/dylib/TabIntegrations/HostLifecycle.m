#import "Native.h"

void DPIntegrationHostResize(DPTabIntegrationHost *host, NSSize size) {
    if (size.width <= 0 || size.height <= 0) return;
    NSEdgeInsets inset = host.shadowInsets;
    NSSize outer = NSMakeSize(size.width + inset.left + inset.right, size.height + inset.top + inset.bottom);
    NSWindow *parent = host.anchor.window;
    if (!parent) return;
    if (host.window.parentWindow && host.window.parentWindow != parent) {
        [host.window.parentWindow removeChildWindow:host.window];
        [parent addChildWindow:host.window ordered:NSWindowAbove];
    }

    NSRect anchor = [parent convertRectToScreen:[host.anchor convertRect:host.anchor.bounds toView:nil]];
    NSRect frame = NSMakeRect(0, 0, outer.width, outer.height);
    if ([DPTabLayout() isEqual:@"vertical"])
        frame.origin = NSMakePoint(NSMaxX(anchor) + 6 - inset.left, NSMidY(anchor) - outer.height / 2);
    else
        frame.origin = NSMakePoint(NSMidX(anchor) - outer.width / 2, NSMinY(anchor) - 6 + inset.top - outer.height);
    NSRect screen = (parent.screen ?: NSScreen.mainScreen).visibleFrame;
    frame.origin.x = MAX(NSMinX(screen), MIN(frame.origin.x, NSMaxX(screen) - frame.size.width));
    frame.origin.y = MAX(NSMinY(screen), MIN(frame.origin.y, NSMaxY(screen) - frame.size.height));
    [host.window setFrame:frame display:host.window.visible];
    [host.root.view layoutSubtreeIfNeeded];
    host.preview.view.frame = host.slot.bounds;
}

void DPIntegrationHostShow(DPTabIntegrationHost *host) {
    host.transition++;
    host.closing = NO;
    host.window.ignoresMouseEvents = NO;
    if (!host.window.visible) {
        host.background.wantsLayer = YES;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        host.background.layer.opacity = 0;
        [CATransaction commit];
    }
    [host.anchor.window addChildWindow:host.window ordered:NSWindowAbove];
    [host.window orderFront:nil];
    for (NSWindow *window in NSApp.windows.copy)
        if (window != host.window && DPReplacesIntegrationHoverWindow(window)) [window orderOut:nil];
    DPTabIntegrationFade(host.background, 1, nil);
}

BOOL DPIntegrationHostContainsPointer(DPTabIntegrationHost *host) {
    if (!host.window.visible) return NO;
    NSRect frame = [host.window convertRectToScreen:[host.background convertRect:host.background.bounds toView:nil]];
    return NSPointInRect(NSEvent.mouseLocation, frame);
}

void DPIntegrationHostClose(DPTabIntegrationHost *host) {
    if (host.closing) return;
    host.closing = YES;
    [host stopPreview];
    NSUInteger transition = ++host.transition;
    if (!host.window.visible) {
        [host.window.parentWindow removeChildWindow:host.window];
        [host.window orderOut:nil];
        return;
    }
    host.window.ignoresMouseEvents = YES;
    DPTabIntegrationFade(host.background, 0, ^{
        if (host.transition != transition || !host.closing) return;
        [host.window.parentWindow removeChildWindow:host.window];
        [host.window orderOut:nil];
    });
}
