#import "Gesture.h"
#import <objc/message.h>
DPLibraryController *DPLibraryForWindow(NSWindow *window);
static id DPLibraryRead(id object,NSString *key) {
    SEL sel = NSSelectorFromString(key);
    return [object respondsToSelector:sel] ? ((id (*)(id,SEL))objc_msgSend)(object,sel) : nil;
}
BOOL DPLibraryAtFirstSpace(NSWindow *window) {
    for (id facade in DPLibraryRead(NSApp.delegate,@"appleScriptWindows")) {
        if (![DPLibraryRead(facade,@"windowId") isEqual:window.identifier]) continue;
        id profile = DPLibraryRead(facade,@"activeProfile"); SEL order = NSSelectorFromString(@"orderedIndex");
        return [profile respondsToSelector:order] && ((NSInteger (*)(id,SEL))objc_msgSend)(profile,order) == 1;
    }
    return NO;
}
void DPLibraryInstallGestures(void) {
    DPLibraryGesture *gesture = [DPLibraryGesture new];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel | NSEventMaskSwipe handler:^NSEvent *(NSEvent *event) {
        return DPLibraryRouteScroll(event,gesture);
    }];
}
