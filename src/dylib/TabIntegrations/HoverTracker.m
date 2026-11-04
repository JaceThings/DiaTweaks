#import "HoverInternal.h"

char DPTabIntegrationTrackerKey;
__weak id DPTabIntegrationCurrentTracker;
NSHashTable *DPTabIntegrationTrackers;

BOOL DPAnyIntegrationEnabled(void) {
    for (NSValue *value in DPRegisteredTabIntegrations())
        if (DPTabIntegrationEnabled(value.pointerValue)) return YES;
    return NO;
}

@implementation DPTabIntegrationHoverTracker
- (BOOL)pointerInside:(NSView *)view {
    if (!view.window || view.hiddenOrHasHiddenAncestor) return NO;
    NSPoint point = [view convertPoint:view.window.mouseLocationOutsideOfEventStream fromView:nil];
    return NSPointInRect(point, view.bounds);
}

- (id)currentTab {
    id tab = DPTabIntegrationTabForView(self.anchor);
    return [[[tab valueForKey:@"tabId"] description] isEqual:self.tabID] ? tab : nil;
}

- (void)reconcile {
    if (!self.host) return;
    id tab = [self currentTab];
    DPTabIntegration *match = tab ? DPTabIntegrationForURL([tab valueForKey:@"URL"]) : NULL;
    if (!tab || match != self.integration || !DPTabIntegrationEnabled(self.integration)
        || self.host.window.parentWindow != self.anchor.window) [self close];
}

- (void)show {
    NSView *anchor = self.anchor;
    id tab = DPTabIntegrationTabForView(anchor);
    NSString *url = [tab valueForKey:@"URL"];
    DPTabIntegration *integration = DPTabIntegrationForURL(url);
    if (!anchor.window || ![self pointerInside:anchor] || !integration || !DPTabIntegrationEnabled(integration)) return;
    [self close];
    [DPTabIntegrationCurrentTracker close];
    DPTabIntegrationPreview *preview = integration->makePreview ? integration->makePreview(integration, tab) : nil;
    if (!preview) return;
    preview.integration = integration;
    preview.tab = tab;
    self.tab = tab;
    self.tabID = [[tab valueForKey:@"tabId"] description];
    self.integration = integration;
    self.host = [[DPTabIntegrationHost alloc] initWithPreview:preview anchor:anchor];
    if (!self.host) { [preview stop]; return; }
    DPTabIntegrationCurrentTracker = self;
    [self.host show];

    __weak DPTabIntegrationHoverTracker *weak = self;
    self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskKeyDown
        handler:^NSEvent *(NSEvent *event) {
            DPTabIntegrationHoverTracker *tracker = weak;
            if (!tracker) return event;
            if (event.type == NSEventTypeKeyDown
                || (event.window != tracker.host.window && ![tracker pointerInside:tracker.anchor]
                    && ![tracker.host containsPointer])) [tracker close];
            return event;
        }];
}

- (void)close {
    if (DPTabIntegrationCurrentTracker == self) DPTabIntegrationCurrentTracker = nil;
    [self.host close];
    self.host = nil;
    if (self.eventMonitor) [NSEvent removeMonitor:self.eventMonitor];
    self.eventMonitor = nil;
    [self.dismiss invalidate];
    self.dismiss = nil;
    self.integration = NULL;
    self.tab = nil;
    self.tabID = nil;
}

- (void)stop {
    [self.reveal invalidate];
    self.reveal = nil;
    [self close];
    if (self.area) [self.anchor removeTrackingArea:self.area];
    self.area = nil;
}

- (void)dealloc {
    [_reveal invalidate];
    [_dismiss invalidate];
    if (_eventMonitor) [NSEvent removeMonitor:_eventMonitor];
    [_host close];
}
@end
