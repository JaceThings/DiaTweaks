#import "Backend.h"
#import <objc/message.h>

const char *const DPTabIntegrationClasses[] = {
    DPDiaBrowser, DPDiaBrowserDelegate, DPDiaTabView, DPDiaPinnedTab, "ArcWebContents", NULL
};

BOOL DPIntegrationBackendAvailable(void) {
    struct { const char *name; SEL selector; } methods[] = {
        { "ArcWebContents", @selector(executeJavascript:completion:) },
        { DPDiaBrowser, @selector(createWebContents:) },
        { DPDiaBrowser, @selector(setWindow:) },
        { DPDiaBrowser, @selector(takeOwnershipOfWebContents:) },
        { DPDiaBrowserDelegate, @selector(browser:didRestoreWebContents:withSessionId:) },
        { DPDiaBrowserDelegate, @selector(browser:didCreateNewWebContents:isActive:) },
    };
    for (NSUInteger i = 0; i < sizeof methods / sizeof *methods; i++)
        if (!class_getInstanceMethod(objc_getClass(methods[i].name), methods[i].selector)) return NO;
    return YES;
}
NSString *DPIntegrationContentsURL(id contents) {
    if (![contents respondsToSelector:@selector(url)]) return nil;
    return DPTabIntegrationURLString(((id (*)(id, SEL))objc_msgSend)(contents, @selector(url)));
}
NSString *DPIntegrationTabURL(id tab) { return DPTabIntegrationURLString([tab valueForKey:@"URL"]); }
BOOL DPIntegrationCanEvaluate(id contents) { return [contents respondsToSelector:@selector(executeJavascript:completion:)]; }
void DPIntegrationExecute(id contents, NSString *script, void (^completion)(NSString *)) {
    if (!DPIntegrationCanEvaluate(contents)) { if (completion) completion(nil); return; }
    ((void (*)(id, SEL, id, id))objc_msgSend)(contents, @selector(executeJavascript:completion:),
        script, ^(NSString *result, BOOL _) { if (completion) completion(result); });
}
