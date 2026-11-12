#import "Patches/Peek/Peek.h"
#import <objc/message.h>

#define DPDiaWindowController "_TtC6Window24PlatformWindowController"

// Dia's Zoom In, Zoom Out and Actual Size zoom the tab behind the card. In a Peek they zoom the Peek's page instead, from the
// menu or by shortcut, so each keeps whatever shortcut its menu item has.

static NSArray<NSString *> *DPPeekZoomActions(void) {
    static NSArray<NSString *> *actions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ actions = @[ @"zoomIn:", @"zoomInAlternate:", @"zoomOut:", @"resetZoom:" ]; });
    return actions;
}

// Chromium's zoom steps.
static const float DPPeekZoomSteps[] = {0.25, 1.0 / 3, 0.5, 2.0 / 3, 0.75, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5};

static BOOL DPPeekZoom(DPPeekCard *peek, SEL action) {
    id page = peek.page;
    SEL get = @selector(zoomFactor), set = @selector(setZoomFactor:), reset = @selector(resetZoomAndScaleFactors);
    if (action == @selector(resetZoom:)) {
        if (![page respondsToSelector:reset]) return NO;
        ((void (*)(id, SEL))objc_msgSend)(page, reset);
        return YES;
    }
    if (![page respondsToSelector:get] || ![page respondsToSelector:set]) return NO;
    float now = ((float (*)(id, SEL))objc_msgSend)(page, get), next;
    size_t count = sizeof DPPeekZoomSteps / sizeof *DPPeekZoomSteps;
    if (action == @selector(zoomOut:)) {
        next = DPPeekZoomSteps[0];
        for (size_t i = count; i-- > 0;) if (DPPeekZoomSteps[i] < now - 0.001) { next = DPPeekZoomSteps[i]; break; }
    } else {
        next = DPPeekZoomSteps[count - 1];
        for (size_t i = 0; i < count; i++) if (DPPeekZoomSteps[i] > now + 0.001) { next = DPPeekZoomSteps[i]; break; }
    }
    ((void (*)(id, SEL, float))objc_msgSend)(page, set, next);
    return YES;
}

static SEL DPPeekZoomShortcutIn(NSMenu *menu, NSEvent *event) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action && [DPPeekZoomActions() containsObject:NSStringFromSelector(item.action)] && DPPeekIsShortcut(event, item)) return item.action;
        SEL action = DPPeekZoomShortcutIn(item.submenu, event);
        if (action) return action;
    }
    return NULL;
}

BOOL DPPeekZoomShortcut(DPPeekCard *peek, NSEvent *event) {
    SEL action = DPPeekZoomShortcutIn(NSApp.mainMenu, event);
    return action && DPPeekZoom(peek, action);
}

static void DPWindow_zoom(NSWindowController *self, SEL _cmd, id sender) {
    DPPeekCard *peek = DPPeekCardIn(self.window);
    if (!peek || !DPPeekZoom(peek, _cmd)) DPCallOriginal(DPWindow_zoom, self, sender);
}

void DPPeekInstallZoom(void) {
    for (NSString *action in DPPeekZoomActions()) DPHook(DPDiaWindowController, NSSelectorFromString(action), (IMP)DPWindow_zoom);
}

NSString *DPPeekZoomProblem(void) {
    Class controller = objc_getClass(DPDiaWindowController);
    for (NSString *action in DPPeekZoomActions())
        if (class_getMethodImplementation(controller, NSSelectorFromString(action)) != (IMP)DPWindow_zoom) return @"zoom doesn't reach Peek";
    return nil;
}
