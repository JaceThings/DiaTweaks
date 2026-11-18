#import "StdPatch/StdPatch.h"
#import <objc/message.h>

extern DPPatch DPZoomOnDoubleClick;
static const CGFloat DPBorderReach = 7;  // Dia keeps a 6 point resize border around the window's content.

// Dia fills the window with content, so the frame view never sees a title bar double-click. It still knows what the
// system asks for, so hand the click to its own handler: fill, zoom, minimise or nothing, whichever System Settings
// has for double-clicking a title bar.
static void DPZoomLikeTitleBar(NSWindow *window) {
    NSView *frame = window.contentView.superview;
    SEL zoom = NSSelectorFromString(@"_zoomWindowWithDoubleClick");
    if ([frame respondsToSelector:zoom]) ((void (*)(id, SEL))objc_msgSend)(frame, zoom);
    else [window zoom:nil];
}

// The first click of a double-click starts Dia's border resize and sits in its tracking loop, which never reaches a
// title bar. A click monitor sees the second click anyway, so that one zooms without letting a resize start.
static NSEvent *DPZoomMouse(NSEvent *event) {
    if (event.type != NSEventTypeLeftMouseDown || !DPZoomOnDoubleClick.on || event.clickCount != 2) return event;
    NSWindow *window = event.window;
    NSView *frame = window.contentView.superview;
    if (!frame || !DPIsKind(window, DPDiaWindow) || (window.styleMask & NSWindowStyleMaskFullScreen)) return event;
    if (event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask) return event;
    NSPoint point = [frame convertPoint:event.locationInWindow fromView:nil];
    CGFloat fromTop = frame.isFlipped ? point.y : NSHeight(frame.bounds) - point.y;
    if (!NSPointInRect(point, frame.bounds) || fromTop > DPBorderReach) return event;
    DPZoomLikeTitleBar(window);
    return nil;
}

static void DPInstallZoomOnDoubleClick(void) {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
                                          handler:^NSEvent *(NSEvent *event) { return DPZoomMouse(event); }];
}

DP_PATCH(DPZoomOnDoubleClick) {
    .key = @"zoomOnDoubleClick",
    .order = 115,
    .title = @"Zoom on Double-Click",
    .detail = @"Double-click the window's top border to fill or zoom it, like a title bar. Follows the system setting for double-clicking a title bar.",
    .symbol = @"arrow.up.left.and.arrow.down.right",
    .tint = @"systemBrownColor",
    .section = @"Window",
    .classes = DPClasses(DPDiaWindow),
    .install = DPInstallZoomOnDoubleClick,
};
