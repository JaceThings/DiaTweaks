#import "HoverInternal.h"

void DPAttachIntegrationHover(NSView *view) {
    if (!DPAnyIntegrationEnabled() || !view.window
        || (!DPIsKind(view, DPDiaTabView) && !DPIsKind(view, DPDiaPinnedTab))) return;
    DPTabIntegrationHoverTracker *existing = DPGet(view, &DPTabIntegrationTrackerKey);
    if (existing) { [existing reconcile]; return; }
    DPTabIntegrationHoverTracker *tracker = [DPTabIntegrationHoverTracker new];
    tracker.anchor = view;
    tracker.area = [[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect
        owner:tracker userInfo:nil];
    [view addTrackingArea:tracker.area];
    DPSet(view, &DPTabIntegrationTrackerKey, tracker);
    if (!DPTabIntegrationTrackers) DPTabIntegrationTrackers = [NSHashTable weakObjectsHashTable];
    [DPTabIntegrationTrackers addObject:tracker];
}

void DPDetachIntegrationHover(NSView *view) {
    DPTabIntegrationHoverTracker *tracker = DPGet(view, &DPTabIntegrationTrackerKey);
    [tracker stop];
    DPSet(view, &DPTabIntegrationTrackerKey, nil);
}

void DPApplyIntegrationHover(void) {
    if (!DPAnyIntegrationEnabled()) { DPDetachAllIntegrationHovers(); return; }
    for (const char *const *name = (const char *[]){DPDiaTabView, DPDiaPinnedTab, NULL}; *name; name++)
        for (NSView *view in DPFindViews(*name)) DPAttachIntegrationHover(view);
    for (DPTabIntegrationHoverTracker *tracker in DPTabIntegrationTrackers.allObjects) [tracker reconcile];
}

void DPDetachAllIntegrationHovers(void) {
    for (DPTabIntegrationHoverTracker *tracker in DPTabIntegrationTrackers.allObjects) {
        NSView *anchor = tracker.anchor;
        if (anchor) DPDetachIntegrationHover(anchor);
        else [tracker stop];
    }
}

void DPDismissIntegrationHover(void) { [DPTabIntegrationCurrentTracker close]; }

BOOL DPReplacesIntegrationHoverWindow(NSWindow *window) {
    if (!DPIsIntegrationNativePreviewWindow(window)) return NO;
    DPTabIntegrationHoverTracker *tracker = DPTabIntegrationCurrentTracker;
    NSView *anchor = tracker.anchor;
    if (!tracker || !tracker.host.window.visible || !anchor.window || !tracker.integration
        || (window.parentWindow && window.parentWindow != anchor.window)) return NO;
    id tab = DPTabIntegrationTabForView(anchor);
    if (!tab || ![[[tab valueForKey:@"tabId"] description] isEqual:tracker.tabID]
        || DPTabIntegrationForURL([tab valueForKey:@"URL"]) != tracker.integration) return NO;
    id content = [window.contentViewController safeSwiftValueForKey:@"contentViewController"];
    id model = [content safeSwiftValueForKey:@"viewModel"];
    NSString *identifier = [[model safeSwiftValueForKey:@"tabID"] description];
    return [identifier isEqual:tracker.tabID]
        && ([tracker pointerInside:anchor] || [tracker.host containsPointer]);
}
