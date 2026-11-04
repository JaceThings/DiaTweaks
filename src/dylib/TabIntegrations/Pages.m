#import "PageHooks.h"
#import <objc/message.h>

@interface DPTabIntegrationPage ()
@property(nonatomic, copy) NSString *observedURL;
@end

static NSMapTable<id, DPTabIntegrationPage *> *DPIntegrationPageMap;
static NSMapTable<id, NSWindow *> *DPIntegrationWindows;
static NSTimer *DPIntegrationPoll;

@implementation DPTabIntegrationPage
@end

static void DPSelectPageIntegration(DPTabIntegrationPage *page) {
    if (!page.contents) return;
    id url = ((id (*)(id, SEL))objc_msgSend)(page.contents, @selector(url));
    NSString *urlString = DPTabIntegrationURLString(url);
    DPTabIntegration *next = DPTabIntegrationForURL(url);
    BOOL urlChanged = page.observedURL ? ![page.observedURL isEqual:urlString] : urlString != nil;
    if (page.integration != next) {
        DPDisposeIntegrationPage(page);
        page.integration = next;
    } else if (urlChanged) {
        page.generation++;
        page.inFlight = NO;
        page.snapshot = nil;
        DPInvalidateIntegrationPageCache(page);
        if (page.integration && page.integration->snapshotChanged) page.integration->snapshotChanged(page);
    }
    page.observedURL = urlString;
}

void DPRememberIntegrationPage(id contents, id browser) {
    if (!contents || !browser) return;
    if (!DPIntegrationPageMap) DPIntegrationPageMap = [NSMapTable weakToStrongObjectsMapTable];
    DPTabIntegrationPage *page = [DPIntegrationPageMap objectForKey:contents] ?: [DPTabIntegrationPage new];
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
        [DPIntegrationPoll invalidate];
        DPIntegrationPoll = nil;
        DPRefreshIntegrationPages();
        return;
    }
    DPRefreshIntegrationPages();
    for (DPTabIntegrationPage *page in DPIntegrationPageMap.objectEnumerator)
        if (page.integration && page.integration->scriptKey) DPTabIntegrationRead(page);
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
        id current = ((id (*)(id, SEL))objc_msgSend)(page.contents, @selector(url));
        if (![DPTabIntegrationURLString(current) isEqual:target]) continue;
        if (match) return nil;
        match = page;
    }
    return match;
}

void DPApplyIntegrationPages(void) {
    DPRefreshIntegrationPages();
    if (!DPHasEnabledScriptIntegration()) {
        [DPIntegrationPoll invalidate];
        DPIntegrationPoll = nil;
        return;
    }
    if (DPIntegrationPoll) return;
    DPIntegrationPoll = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *_) {
        DPIntegrationPollTick();
    }];
    [NSRunLoop.mainRunLoop addTimer:DPIntegrationPoll forMode:NSRunLoopCommonModes];
    [DPIntegrationPoll fire];
}

void DPInstallIntegrationPages(void) {
    if (!DPIntegrationPageMap) DPIntegrationPageMap = [NSMapTable weakToStrongObjectsMapTable];
    if (!DPIntegrationWindows) DPIntegrationWindows = [NSMapTable weakToWeakObjectsMapTable];
    DPInstallIntegrationPageHooks();
    DPOnLaunch(^{ DPApplyIntegrationPages(); });
}
