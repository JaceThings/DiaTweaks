#import "SidebarNavigation.h"

static BOOL DPOwnedNative(DPNavigationSlot *slot) { return slot.owner && !slot.moving; }

static void DPNavigationNative_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPNavigationSlot *slot = DPNavigationSlotFor(self);
    BOOL moving = slot.moving;
    if (DPOwnedNative(slot)) {
        slot.originalFrame = frame;
        frame = slot.forcedFrame;
        slot.moving = YES;
    }
    DPCallOriginal(DPNavigationNative_setFrame, self, frame);
    if (slot) slot.moving = moving;
}

static void DPNavigationNative_setOrigin(NSView *self, SEL _cmd, NSPoint origin) {
    DPNavigationSlot *slot = DPNavigationSlotFor(self);
    if (DPOwnedNative(slot)) { slot.originalFrame = (NSRect){origin, slot.originalFrame.size}; origin = slot.forcedFrame.origin; }
    DPCallOriginal(DPNavigationNative_setOrigin, self, origin);
}

static void DPNavigationNative_setSize(NSView *self, SEL _cmd, NSSize size) {
    DPNavigationSlot *slot = DPNavigationSlotFor(self);
    if (DPOwnedNative(slot)) {
        slot.originalFrame = (NSRect){slot.originalFrame.origin, size};
        size = slot.forcedFrame.size;
    }
    DPCallOriginal(DPNavigationNative_setSize, self, size);
}

static void DPNavigationNative_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPNavigationSlot *slot = DPNavigationSlotFor(self);
    if (DPOwnedNative(slot)) { slot.originalHidden = hidden; hidden = slot.forcedHidden; }
    DPCallOriginal(DPNavigationNative_setHidden, self, hidden);
}

static void DPNavigationNative_setAlpha(NSView *self, SEL _cmd, CGFloat alpha) {
    DPNavigationSlot *slot = DPNavigationSlotFor(self);
    if (DPOwnedNative(slot)) { slot.originalAlpha = alpha; alpha = 1; }
    DPCallOriginal(DPNavigationNative_setAlpha, self, alpha);
}

void DPNavigationInstallControlHooks(NSView *view) {
    DPHookClass(view.class, @selector(setFrame:), (IMP)DPNavigationNative_setFrame);
    DPHookClass(view.class, @selector(setFrameOrigin:), (IMP)DPNavigationNative_setOrigin);
    DPHookClass(view.class, @selector(setFrameSize:), (IMP)DPNavigationNative_setSize);
    DPHookClass(view.class, @selector(setHidden:), (IMP)DPNavigationNative_setHidden);
    DPHookClass(view.class, @selector(setAlphaValue:), (IMP)DPNavigationNative_setAlpha);
}
