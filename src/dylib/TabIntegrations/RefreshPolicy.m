#import "Internal.h"
#import <math.h>

NSTimeInterval DPIntegrationRefreshDelay(DPTabIntegrationPage *page) {
    BOOL observed = DPIntegrationPageIsObserved(page);
    NSTimeInterval delay = observed ? page.integration->refreshInterval : page.integration->backgroundRefreshInterval;
    if (!isfinite(delay) || delay <= 0) delay = observed ? 0.5 : 2;
    delay = MAX(0.5, delay);
    // A provider's intentionally slow schedule must not get faster after a failure.
    return page.failureCount ? MAX(delay, MIN(30, delay * pow(2, MIN(page.failureCount, 6)))) : delay;
}

BOOL DPIntegrationExpireRequest(DPTabIntegrationPage *page, NSTimeInterval now) {
    if (!page.inFlight || !page.integration) return NO;
    NSTimeInterval timeout = page.integration->requestTimeout;
    if (!isfinite(timeout) || timeout <= 0) timeout = 10;
    if (now - page.requestedAt <= timeout) return NO;
    page.generation++;
    page.inFlight = NO;
    page.requestedAt = now;
    page.failureCount++;
    page.diagnosticCode = page.lastFailure = @"timeout";
    return YES;
}
