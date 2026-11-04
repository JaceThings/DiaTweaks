#import "Internal.h"
#import "ScriptBuilders.h"
#import "Backend.h"

static void DPIntegrationEvaluate(DPTabIntegrationPage *page, NSString *script, void (^done)(NSDictionary *)) {
    DPIntegrationExecute(page.contents, script, ^(NSString *result) {
        NSDictionary *decoded = DPTabIntegrationDecode(result);
        dispatch_async(dispatch_get_main_queue(), ^{ done(decoded); });
    });
}

static BOOL DPIntegrationCallbackCurrent(DPTabIntegrationPage *page, DPTabIntegration *integration,
                                         NSUInteger generation, NSString *capturedURL) {
    if (!page || page.generation != generation || page.integration != integration || !DPTabIntegrationEnabled(integration)) return NO;
    id url = DPIntegrationContentsURL(page.contents);
    return [DPTabIntegrationURLString(url) isEqual:capturedURL] && DPTabIntegrationMatchesURL(integration, url);
}

static void DPIntegrationStoreResult(DPTabIntegrationPage *page, DPTabIntegration *integration,
                                     NSUInteger generation, NSString *capturedURL, NSDictionary *result) {
    if (!page || page.generation != generation) return;
    page.inFlight = NO;
    if (!DPIntegrationCallbackCurrent(page, integration, generation, capturedURL)) return;
    if (!result) {
        page.failureCount++;
        page.diagnosticCode = page.lastFailure = @"read-failed";
        return;
    }
    page.snapshot = result;
    page.receivedAt = NSDate.timeIntervalSinceReferenceDate;
    page.failureCount = 0;
    page.diagnosticCode = @"ready";
    page.lastFailure = nil;
    if (integration->snapshotChanged) integration->snapshotChanged(page);
}

void DPTabIntegrationRead(DPTabIntegrationPage *page) {
    if (!page) return;
    DPTabIntegration *integration = page.integration;
    if (!integration || !integration->scriptKey || !DPTabIntegrationEnabled(integration)) return;
    id currentURL = DPIntegrationContentsURL(page.contents);
    if (!DPTabIntegrationMatchesURL(integration, currentURL)) return;
    if (!DPIntegrationCanEvaluate(page.contents)) { page.diagnosticCode = @"transport-unavailable"; return; }
    DPIntegrationExpireRequest(page, NSDate.timeIntervalSinceReferenceDate);
    if (page.inFlight) return;
    page.inFlight = YES;
    page.requestedAt = NSDate.timeIntervalSinceReferenceDate;
    page.diagnosticCode = @"reading";
    NSUInteger generation = page.generation;
    NSString *capturedURL = DPTabIntegrationURLString(currentURL);
    NSString *poll = DPIntegrationBuildPollScript(integration);
    if (!poll) { page.inFlight = NO; page.diagnosticCode = @"invalid-descriptor"; return; }
    DPIntegrationEvaluate(page, poll, ^(NSDictionary *result) {
        if (page.generation != generation) return;
        if (!DPIntegrationCallbackCurrent(page, integration, generation, capturedURL)) { page.inFlight = NO; return; }
        if ([result[@"installNeeded"] isKindOfClass:NSNumber.class] && [result[@"installNeeded"] boolValue]) {
            NSString *source = DPTabIntegrationScript(integration->scriptKey);
            NSString *install = DPIntegrationBuildInstallScript(integration, source);
            if (!install) { page.inFlight = NO; page.diagnosticCode = @"script-unavailable"; return; }
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
    id currentURL = DPIntegrationContentsURL(page.contents);
    if (!DPTabIntegrationMatchesURL(integration, currentURL)) return;
    NSString *script = DPIntegrationBuildCommandScript(integration, method, arguments);
    if (!script) return;
    page.generation++;
    page.inFlight = YES;
    page.requestedAt = NSDate.timeIntervalSinceReferenceDate;
    page.diagnosticCode = @"reading";
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
    page.requestedAt = 0;
    page.receivedAt = 0;
    page.failureCount = 0;
    page.lastFailure = nil;
    page.diagnosticCode = @"disposed";
    DPInvalidateIntegrationPageCache(page);
    if (integration && integration->snapshotChanged) integration->snapshotChanged(page);
    if (!integration || !integration->scriptKey || !integration->scriptNamespace || !page.contents) return;
    NSString *script = DPIntegrationBuildDisposeScript(integration);
    if (!script) return;
    DPIntegrationExecute(page.contents, script, nil);
}
