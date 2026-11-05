#import "PageHooks.h"
#import "Backend.h"
#import "Scheduler.h"

@interface DPTabIntegrationPage ()
@property(nonatomic, copy) NSString *observedURL;
@end

static NSMapTable<id, DPTabIntegrationPage *> *DPIntegrationPageMap;
static NSMapTable<id, NSWindow *> *DPIntegrationWindows;
static DPIntegrationSubscription *DPIntegrationPoll;

@implementation DPTabIntegrationPage
@end

static void DPSelectPageIntegration(DPTabIntegrationPage *page) {
    if (!page.contents) return;
    id url = DPIntegrationContentsURL(page.contents);
    NSString *urlString = DPTabIntegrationURLString(url);
    DPTabIntegration *next = DPTabIntegrationForURL(url);
    BOOL urlChanged = page.observedURL ? ![page.observedURL isEqual:urlString] : urlString != nil;
    if (page.integration != next) {
        DPDisposeIntegrationPage(page);
        page.integration = next;
        page.diagnosticCode = next ? @"not-requested" : @"no-provider";
    } else if (urlChanged) {
        page.generation++;
        page.inFlight = NO;
        page.snapshot = nil;
        page.requestedAt = 0;
        page.failureCount = 0;
        page.lastFailure = nil;
        page.diagnosticCode = @"not-requested";
        DPInvalidateIntegrationPageCache(page);
        if (page.integration && page.integration->snapshotChanged) page.integration->snapshotChanged(page);
    }
    page.observedURL = urlString;
}

void DPRememberIntegrationPage(id contents, id browser) {
    if (!contents || !browser) return;
    if (!DPIntegrationPageMap) DPIntegrationPageMap = [NSMapTable weakToStrongObjectsMapTable];
    DPTabIntegrationPage *page = [DPIntegrationPageMap objectForKey:contents] ?: [DPTabIntegrationPage new];
    if (page.browser && page.browser != browser) DPDisposeIntegrationPage(page);
    page.contents = contents;
    page.browser = browser;
    [DPIntegrationPageMap setObject:page forKey:contents];
    DPSelectPageIntegration(page);
}

void DPIntegrationSetBrowserWindow(id browser, NSWindow *window) {
    if (!DPIntegrationWindows) DPIntegrationWindows = [NSMapTable weakToWeakObjectsMapTable];
    if (window) [DPIntegrationWindows setObject:window forKey:browser];
    else [DPIntegrationWindows removeObjectForKey:browser];
}

static BOOL DPHasEnabledScriptIntegration(void) {
    for (NSValue *value in DPRegisteredTabIntegrations()) {
        DPTabIntegration *integration = value.pointerValue;
        if (integration && integration->scriptKey && DPTabIntegrationEnabled(integration)) return YES;
    }
    return NO;
}

static void DPRefreshIntegrationPages(void) {
    for (DPTabIntegrationPage *page in DPIntegrationPageMap.objectEnumerator)
        DPSelectPageIntegration(page);
}

static void DPIntegrationPollTick(void) {
    if (!DPHasEnabledScriptIntegration()) {
        [DPIntegrationPoll cancel];
        DPIntegrationPoll = nil;
        DPRefreshIntegrationPages();
        return;
    }
    DPRefreshIntegrationPages();
    NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
    for (DPTabIntegrationPage *page in DPIntegrationPageMap.objectEnumerator) {
        if (!page.integration || !page.integration->scriptKey) continue;
        DPIntegrationExpireRequest(page, now);
        if (!page.inFlight && (page.requestedAt <= 0 || now - page.requestedAt >= DPIntegrationRefreshDelay(page)))
            DPTabIntegrationRead(page);
    }
}

NSArray<DPTabIntegrationPage *> *DPTabIntegrationPages(DPTabIntegration *integration, NSWindow *window) {
    if (!integration || !DPTabIntegrationEnabled(integration)) return @[];
    NSMutableArray *pages = [NSMutableArray new];
    for (DPTabIntegrationPage *page in DPIntegrationPageMap.objectEnumerator) {
        DPSelectPageIntegration(page);
        if (page.integration != integration || !page.contents || !page.browser) continue;
        if (window && [DPIntegrationWindows objectForKey:page.browser] != window) continue;
        [pages addObject:page];
    }
    return pages;
}

DPTabIntegrationPage *DPTabIntegrationPageForURL(DPTabIntegration *integration, NSWindow *window, id url) {
    NSString *target = DPTabIntegrationURLString(url);
    DPTabIntegrationPage *match = nil;
    for (DPTabIntegrationPage *page in DPTabIntegrationPages(integration, window)) {
        id current = DPIntegrationContentsURL(page.contents);
        if (![DPTabIntegrationURLString(current) isEqual:target]) continue;
        if (match) return nil;
        match = page;
    }
    return match;
}

void DPApplyIntegrationPages(void) {
    DPRefreshIntegrationPages();
    if (!DPHasEnabledScriptIntegration()) {
        [DPIntegrationPoll cancel];
        DPIntegrationPoll = nil;
        return;
    }
    if (DPIntegrationPoll) return;
    DPIntegrationPoll = DPIntegrationSchedule(^(NSTimeInterval now) {
        DPIntegrationPollTick();
    });
    DPIntegrationPollTick();
}

void DPInstallIntegrationPages(void) {
    if (!DPIntegrationPageMap) DPIntegrationPageMap = [NSMapTable weakToStrongObjectsMapTable];
    if (!DPIntegrationWindows) DPIntegrationWindows = [NSMapTable weakToWeakObjectsMapTable];
    DPInstallIntegrationPageHooks();
    DPOnLaunch(^{ DPApplyIntegrationPages(); });
}
