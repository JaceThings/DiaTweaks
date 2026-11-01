#import "Peek.h"

BOOL DPPeekCheckABI(void) {
    struct { const char *cls, *selector, *encoding; } methods[] = {
        {"ArcBrowser", "setWindow:", "v24@0:8@16"},
        {"ArcBrowser", "createWebContents:", "@24@0:8@16"},
        {"ArcBrowser", "takeOwnershipOfWebContents:", "v24@0:8@16"},
        {DPDiaBrowserDelegate, "browser:didRestoreWebContents:withSessionId:", "v40@0:8@16@24@32"},
        {DPDiaBrowserDelegate, "browser:didCreateNewWebContents:isActive:", "v36@0:8@16@24B32"},
        {"ArcWebContents", "createPaneHostView", "@16@0:8"},
        {"ArcWebContents", "nativeView", "@16@0:8"},
        {"ArcNavigationAction", "url", "@16@0:8"},
        {"ArcWebContents", "attachToPaneHostView:", "v24@0:8@16"},
        {"ArcWebContents", "detachFromPaneHostView:", "v24@0:8@16"},
        {"ArcWebContents", "navigationController", "@16@0:8"},
        {"ArcWebContents", "stop", "v16@0:8"},
        {"ArcWebContents", "setNavigationDelegate:", "v24@0:8@16"},
        {"ArcWebContentsConfiguration", "setForeground:", "v20@0:8B16"},
        {"ArcWebContentsConfiguration", "setUntracked:", "v20@0:8B16"},
        {"ArcWebContentsNavigationController", "load:initiatorOrigin:", "@32@0:8@16@24"},
        {"ArcNavigationAction", "navigationType", "Q16@0:8"},
        {"_TtC3ADK18WebContentChromium", "webContents:decidePolicyForNavigationAction:", "q32@0:8@16@24"},
    };
    for (NSUInteger i = 0; i < sizeof(methods) / sizeof(methods[0]); i++) {
        Method method = class_getInstanceMethod(objc_getClass(methods[i].cls), sel_registerName(methods[i].selector));
        const char *encoding = method ? method_getTypeEncoding(method) : NULL;
        if (!encoding || strcmp(encoding, methods[i].encoding)) {
            NSLog(@"DiaPatches Peek: unsupported method %s %s", methods[i].cls, methods[i].selector);
            return NO;
        }
    }
    return YES;
}
