#import "Controller.h"

BOOL DPPeekOpen(id sourceContents, NSURL *url, NSPoint clickInWindow) {
    id browser = DPPeekBrowser(sourceContents);
    NSView *source = [sourceContents nativeView], *container = source.superview;
    // Chromium's pane host owns its compositing. Overlay its Dia parent, not the host itself.
    while (container && !DPIsKind(container, DPDiaContentPane)) container = container.superview;
    NSRect frame = [container convertRect:source.bounds fromView:source];
    if (!browser || !source.window || source.hiddenOrHasHiddenAncestor || !container || frame.size.width < 320 || frame.size.height < 240) return NO;
    DPPeekCloseContents(sourceContents);
    DPPeekController *controller = [DPPeekController new];
    controller.sourceContents = sourceContents;
    controller.source = source;
    @try {
        id configuration = [NSClassFromString(@"ArcWebContentsConfiguration") new];
        [configuration setForeground:YES];
        [configuration setUntracked:YES];
        controller.contents = [browser createWebContents:configuration];
        if (!controller.contents) return NO;
        NSView *host = [controller.contents createPaneHostView];
        if (![host isKindOfClass:NSView.class]) { [controller close]; return NO; }
        controller.overlay = [[DPPeekOverlay alloc] initWithFrame:frame];
        controller.overlay.heading.stringValue = url.host ?: @"Peek";
        controller.overlay.host = host;
        [controller.overlay.card addSubview:host positioned:NSWindowBelow relativeTo:nil];
        __weak DPPeekController *weak = controller;
        controller.overlay.dismiss = ^{ [weak dismiss]; };
        if (!DPPeekControllers) DPPeekControllers = [NSMutableSet new];
        [DPPeekControllers addObject:controller];
        [container addSubview:controller.overlay positioned:NSWindowAbove relativeTo:nil];
        controller.overlay.needsLayout = YES;
        [controller.overlay layoutSubtreeIfNeeded];
        controller.overlay.origin = [controller.overlay convertPoint:clickInWindow fromView:nil];
        [controller.contents attachToPaneHostView:host];
        controller.keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
            DPPeekController *preview = weak;
            if (preview.overlay.window == event.window && !preview.overlay.hiddenOrHasHiddenAncestor && event.keyCode == 53) {
                [preview dismiss];
                return nil;
            }
            return event;
        }];
        id navigation = [[controller.contents navigationController] load:url initiatorOrigin:nil];
        if (!navigation) { [controller close]; return NO; }
        [source.window makeFirstResponder:host];
        DPPeekAnimate(controller.overlay, YES, nil);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"DiaPatches Peek: native preview failed (%@)", exception.name);
        [controller close];
        return NO;
    }
}
