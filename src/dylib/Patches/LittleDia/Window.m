#import "LittleDia.h"

static const NSTimeInterval DPLittleHideDuration = 0.15, DPScrimDuration = 0.2;
static const CGFloat DPScrimOpacity = 0.25;
static NSView *DPScrim;

BOOL DPLittleAlive(NSWindow *window) {
    return window && DPLittleID(window) && [NSApp.windows containsObject:window];
}

NSView *DPLittleSidebarHeader(NSWindow *window) {
    NSView *header = DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaSidebarHeader); });
    if (!header || header.isHiddenOrHasHiddenAncestor) return nil;
    NSRect frame = [header convertRect:header.bounds toView:nil];
    return NSWidth(frame) < 1 || NSMaxX(frame) <= 1 ? nil : header;
}

// Sent up the sidebar's own responder chain, so it works before the window becomes key.
void DPCollapseSidebar(NSWindow *window) {
    NSView *header = DPLittleSidebarHeader(window);
    SEL toggle = NSSelectorFromString(@"toggleSidebar:");
    if (header && ![header tryToPerform:toggle with:nil] && window.isKeyWindow) [NSApp sendAction:toggle to:nil from:nil];
}

// Dims the window Little Dia opened over; a click on it dismisses Little Dia, like clicking outside a popover.
@interface DPScrimView : NSView
@end

@implementation DPScrimView
- (NSView *)hitTest:(NSPoint)point { return NSPointInRect([self convertPoint:point fromView:self.superview], self.bounds) ? self : nil; }
- (void)mouseDown:(NSEvent *)event { DPHideLittle(DPLittle); }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
@end

// The window Little Dia opens over: the one in use, or Dia's frontmost when a link comes from another app.
NSWindow *DPLittleParent(void) {
    NSMutableArray<NSWindow *> *candidates = [NSMutableArray arrayWithObject:NSApp.mainWindow ?: NSNull.null];
    [candidates addObjectsFromArray:NSApp.orderedWindows];
    for (id window in candidates)
        if ([window isKindOfClass:NSWindow.class] && [window canBecomeMainWindow] && [window isVisible] && ![window isMiniaturized]
            && ![DPLittleWindows containsObject:window]) return window;
    return nil;
}

static void DPShowScrim(NSWindow *parent) {
    NSView *frame = parent.contentView.superview;
    if (!frame) return;
    if (!DPScrim) {
        DPScrim = [DPScrimView new];
        DPScrim.wantsLayer = YES;
        DPScrim.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:DPScrimOpacity].CGColor;
        DPScrim.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    DPScrim.frame = frame.bounds;
    DPScrim.alphaValue = 0;
    [frame addSubview:DPScrim positioned:NSWindowAbove relativeTo:nil];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPScrimDuration;
        DPScrim.animator.alphaValue = 1;
    }];
}

// A child window rides along with the window it opened over and isn't listed as a window of its own.
void DPAttachLittle(NSWindow *window, NSWindow *parent) {
    for (NSWindowButton type = NSWindowCloseButton; type <= NSWindowZoomButton; type++) [window standardWindowButton:type].hidden = YES;
    if (!parent) return;
    if (window.parentWindow != parent) {
        [window.parentWindow removeChildWindow:window];
        [parent addChildWindow:window ordered:NSWindowAbove];
    }
    DPShowScrim(parent);
}

// Hidden rather than closed, and emptied so nothing keeps playing behind the scenes.
void DPHideLittle(NSWindow *window) {
    if (!DPLittleAlive(window) || !window.isVisible || DPLittleOpening) return;
    NSString *windowID = DPLittleID(window);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPLittleHideDuration;
        window.animator.alphaValue = 0;
        DPScrim.animator.alphaValue = 0;
    } completionHandler:^{
        if (DPLittleOpening) return;
        [DPScrim removeFromSuperview];
        [window.parentWindow removeChildWindow:window];
        [window orderOut:nil];
        DPDiaScript([NSString stringWithFormat:@"set URL of active tab of window id %@ to \"about:blank\"", DPQuoted(windowID)]);
    }];
}
