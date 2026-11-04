#import "Internal.h"
#import "ScriptBuilders.h"
#import <objc/message.h>

static void DPIntegrationEvaluate(DPTabIntegrationPage *page, NSString *script, void (^done)(NSDictionary *)) {
    SEL selector = @selector(executeJavascript:completion:);
    if (![page.contents respondsToSelector:selector]) return done(nil);
    ((void (*)(id, SEL, id, id))objc_msgSend)(page.contents, selector, script, ^(NSString *result, BOOL _) {
        NSDictionary *decoded = DPTabIntegrationDecode(result);
        dispatch_async(dispatch_get_main_queue(), ^{ done(decoded); });
    });
}

static BOOL DPIntegrationCallbackCurrent(DPTabIntegrationPage *page, DPTabIntegration *integration,
                                         NSUInteger generation, NSString *capturedURL) {
    if (!page || page.generation != generation || page.integration != integration || !DPTabIntegrationEnabled(integration)) return NO;
    id url = ((id (*)(id, SEL))objc_msgSend)(page.contents, @selector(url));
    return [DPTabIntegrationURLString(url) isEqual:capturedURL] && DPTabIntegrationMatchesURL(integration, url);
}

static void DPIntegrationStoreResult(DPTabIntegrationPage *page, DPTabIntegration *integration,
                                     NSUInteger generation, NSString *capturedURL, NSDictionary *result) {
    if (!page || page.generation != generation) return;
    page.inFlight = NO;
    if (!result || !DPIntegrationCallbackCurrent(page, integration, generation, capturedURL)) return;
    page.snapshot = result;
    page.receivedAt = NSDate.timeIntervalSinceReferenceDate;
    if (integration->snapshotChanged) integration->snapshotChanged(page);
}

void DPTabIntegrationRead(DPTabIntegrationPage *page) {
    if (!page) return;
    DPTabIntegration *integration = page.integration;
    if (!integration || !integration->scriptKey || !DPTabIntegrationEnabled(integration)) return;
    id currentURL = ((id (*)(id, SEL))objc_msgSend)(page.contents, @selector(url));
    if (!DPTabIntegrationMatchesURL(integration, currentURL)) return;
    if (page.inFlight && NSDate.timeIntervalSinceReferenceDate - page.requestedAt <= 10) return;
    if (page.inFlight) page.generation++;
    page.inFlight = YES;
    page.requestedAt = NSDate.timeIntervalSinceReferenceDate;
    NSUInteger generation = page.generation;
    NSString *capturedURL = DPTabIntegrationURLString(currentURL);
    NSString *poll = DPIntegrationBuildPollScript(integration);
    if (!poll) { page.inFlight = NO; return; }
    DPIntegrationEvaluate(page, poll, ^(NSDictionary *result) {
        if (page.generation != generation) return;
        if (!DPIntegrationCallbackCurrent(page, integration, generation, capturedURL)) { page.inFlight = NO; return; }
        if ([result[@"installNeeded"] isKindOfClass:NSNumber.class] && [result[@"installNeeded"] boolValue]) {
            NSString *source = DPTabIntegrationScript(integration->scriptKey);
            NSString *install = DPIntegrationBuildInstallScript(integration, source);
            if (!install) { page.inFlight = NO; return; }
            DPIntegrationEvaluate(page, install, ^(NSDictionary *snapshot) {
                DPIntegrationStoreResult(page, integration, generation, capturedURL, snapshot);
            });
            return;
        }
        DPIntegrationStoreResult(page, integration, generation, capturedURL, result);
    });
}

void DPTabIntegrationCommand(DPTabIntegrationPage *page, NSString *method, NSArray *arguments) {
    if (!page) return;
    DPTabIntegration *integration = page.integration;
    if (!integration || !integration->scriptKey || !DPTabIntegrationEnabled(integration)) return;
    id currentURL = ((id (*)(id, SEL))objc_msgSend)(page.contents, @selector(url));
    if (!DPTabIntegrationMatchesURL(integration, currentURL)) return;
    NSString *script = DPIntegrationBuildCommandScript(integration, method, arguments);
    if (!script) return;
    page.generation++;
    page.inFlight = YES;
    page.requestedAt = NSDate.timeIntervalSinceReferenceDate;
    NSUInteger generation = page.generation;
    NSString *capturedURL = DPTabIntegrationURLString(currentURL);
    DPIntegrationEvaluate(page, script, ^(NSDictionary *result) {
        DPIntegrationStoreResult(page, integration, generation, capturedURL, result);
    });
}

void DPDisposeIntegrationPage(DPTabIntegrationPage *page) {
    if (!page) return;
    DPTabIntegration *integration = page.integration;
    page.generation++;
    page.inFlight = NO;
    page.snapshot = nil;
    DPInvalidateIntegrationPageCache(page);
    if (integration && integration->snapshotChanged) integration->snapshotChanged(page);
    if (!integration || !integration->scriptKey || !integration->scriptNamespace || !page.contents) return;
    NSString *script = DPIntegrationBuildDisposeScript(integration);
    if (!script) return;
    SEL selector = @selector(executeJavascript:completion:);
    if ([page.contents respondsToSelector:selector])
        ((void (*)(id, SEL, id, id))objc_msgSend)(page.contents, selector, script, ^(NSString *_, BOOL __) {});
}
