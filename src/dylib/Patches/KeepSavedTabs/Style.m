#import "KeepSavedTabs.h"
#import <objc/message.h>

// Open saved tabs get "–" in place of ✕. Saved tabs with nothing open have nothing to close.

static char DPCloseImageKey, DPDiaHiddenKey;

static void DPStyleCloseButton(NSButton *close, BOOL dash) {
    id original = DPGet(close, &DPCloseImageKey);
    if (dash && !original) {
        DPSet(close, &DPCloseImageKey, close.image ?: NSNull.null);
        NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightSemibold];
        close.image = [[NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:@"Close page"] imageWithSymbolConfiguration:config];
    } else if (!dash && original) {
        close.image = [original isKindOfClass:NSImage.class] ? original : nil;
        DPSet(close, &DPCloseImageKey, nil);
    }
}

// Tab close buttons move to a subclass of their own to stay hidden, so this never touches other buttons' setHidden:.
static void DPSavedClose_setHidden(NSButton *self, SEL _cmd, BOOL hidden) {
    DPSet(self, &DPDiaHiddenKey, @(hidden));
    NSView *tab = DPSavedEnclosing(self, objc_getClass(DPDiaTabView));
    if (!hidden && tab && DPKeepSavedTabs.on && DPSavedKeepsTab(tab) && !DPSavedHasPage(tab)) hidden = YES;
    struct objc_super parent = {self, class_getSuperclass(object_getClass(self))};
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&parent, _cmd, hidden);
}

static Class DPSavedClose_class(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

static void DPAdoptCloseButton(NSButton *close) {
    static Class subclass;
    Class base = object_getClass(close);
    if (base == subclass) return;
    if (!subclass) {
        subclass = objc_allocateClassPair(base, "DPSavedTabCloseButton", 0);
        class_addMethod(subclass, @selector(setHidden:), (IMP)DPSavedClose_setHidden, "v@:B");
        class_addMethod(subclass, @selector(class), (IMP)DPSavedClose_class, "#@:");
        objc_registerClassPair(subclass);
    }
    if (class_getSuperclass(subclass) == base) object_setClass(close, subclass);
}

void DPSavedUpdate(NSView *tab) {
    BOOL saved = DPKeepSavedTabs.on && DPSavedKeepsTab(tab);
    BOOL live = saved && DPSavedHasPage(tab);
    NSButton *close = DPSavedCloseButton(tab);
    if (!close) return;
    DPAdoptCloseButton(close);
    DPStyleCloseButton(close, live);
    if (saved && !live) {
        if (close.hidden) return;
        close.hidden = YES;
        DPSet(close, &DPDiaHiddenKey, @NO);
    } else if (close.hidden && [DPGet(close, &DPDiaHiddenKey) isEqual:@NO]) {
        // Dia shows the button when the pointer enters the tab and doesn't ask again, so a page opened by clicking the tab
        // would otherwise get its "–" only after the pointer leaves and comes back.
        NSPoint pointer = [tab convertPoint:tab.window.mouseLocationOutsideOfEventStream fromView:nil];
        if (NSPointInRect(pointer, tab.bounds)) close.hidden = NO;
    }
}

static void DPTab_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTab_layout, self);
    DPSavedUpdate(self);
}

void DPInstallSavedStyle(void) {
    DPHook(DPDiaTabView, @selector(layout), (IMP)DPTab_layout);
}
