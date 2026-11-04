#import "HoverInternal.h"

NSString *DPVerifyIntegrationHover(DPTabIntegration *integration) {
    if (!integration) return @"Tab integration is unavailable";
    if (DPTabIntegrationEnabled(integration) && !DPIntegrationHostAvailable()) return @"Dia's native tab preview is unavailable";
    BOOL anyEnabled = DPAnyIntegrationEnabled(), fitChecked = NO;
    for (const char *const *name = (const char *[]){DPDiaTabView, DPDiaPinnedTab, NULL}; *name; name++)
        for (NSView *view in DPFindViews(*name)) {
            id tab = DPTabIntegrationTabForView(view);
            if (!tab || !DPTabIntegrationMatchesURL(integration, [tab valueForKey:@"URL"])) continue;
            DPTabIntegrationHoverTracker *tracker = DPGet(view, &DPTabIntegrationTrackerKey);
            BOOL watches = NO;
            for (NSTrackingArea *area in view.trackingAreas)
                watches |= tracker && area == tracker.area && area.owner == tracker;
            if (anyEnabled != watches)
                return anyEnabled ? @"Matching tab has no integration hover tracker" : @"Integration hover tracker remains while all sites are off";
            if (tracker.host && (!tracker.integration || !DPTabIntegrationEnabled(tracker.integration)
                || DPTabIntegrationForURL([tab valueForKey:@"URL"]) != tracker.integration))
                return @"A stale integration preview is still open";
            if (DPTabIntegrationEnabled(integration) && !fitChecked) {
                if (!integration->makePreview) return @"Integration preview provider is unavailable";
                DPTabIntegrationPreview *preview = integration->makePreview(integration, tab);
                if (!preview) return @"Integration preview provider returned no view";
                preview.integration = integration;
                preview.tab = tab;
                DPTabIntegrationHost *host = [[DPTabIntegrationHost alloc] initWithPreview:preview anchor:view];
                BOOL fits = host && !host.window.visible && preview.view.superview == host.slot
                    && preview.preferredContentSize.width > 0 && preview.preferredContentSize.height > 0
                    && NSEqualSizes(preview.view.frame.size, host.slot.bounds.size);
                [host close];
                if (!host) [preview stop];
                if (!fits) return @"Dia's native hover container did not fit the integration preview";
                fitChecked = YES;
            }
        }
    return nil;
}
