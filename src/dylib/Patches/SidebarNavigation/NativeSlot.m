#import "SidebarNavigation.h"

static char DPNativeSlotKey;
@implementation DPNavigationSlot @end
DPNavigationSlot *DPNavigationSlotFor(NSView *view) { return DPGet(view, &DPNativeSlotKey); }

// Dia still owns these controls and can remove them while changing profiles.
static void DPNavigationStackRemove(NSStackView *self, SEL _cmd, NSView *view, BOOL animated, BOOL removeFromHierarchy) {
    DPNavigationSlot *slot = DPNavigationSlotFor(view);
    if (slot.home == self && !slot.moving && view.superview != self)
        DPNavigationRestore(slot);
    DPCallOriginal(DPNavigationStackRemove,self,view,animated,removeFromHierarchy);
}

DPNavigationSlot *DPNavigationAttach(NSView *view, NSView *owner, NSView *destination, NSRect frame) {
    if (!view || !view.superview || DPNavigationSlotFor(view)) return nil;
    DPNavigationSlot *slot = [DPNavigationSlot new];
    slot.view = view; slot.home = view.superview; slot.owner = owner;
    slot.originalFrame = view.frame; slot.forcedFrame = frame;
    slot.originalHidden = view.hidden; slot.originalAlpha = view.alphaValue;
    slot.originalMask = view.autoresizingMask; slot.originalTranslates = view.translatesAutoresizingMaskIntoConstraints;
    slot.index = [slot.home.subviews indexOfObjectIdenticalTo:view];
    slot.moving = YES;
    DPSet(view, &DPNativeSlotKey, slot);
    DPNavigationInstallControlHooks(view);
    if ([slot.home isKindOfClass:NSStackView.class]) {
        NSStackView *stack = (NSStackView *)slot.home;
        DPHookClass(stack.class,NSSelectorFromString(@"_removeView:animated:removeFromViewHierarchy:"),(IMP)DPNavigationStackRemove);
        for (NSNumber *gravity in @[@(NSStackViewGravityLeading), @(NSStackViewGravityCenter), @(NSStackViewGravityTrailing)]) {
            NSUInteger index = [[stack viewsInGravity:gravity.integerValue] indexOfObjectIdenticalTo:view];
            if (index != NSNotFound) { slot.gravity = gravity.integerValue; slot.index = index; break; }
        }
        [stack removeView:view];
    } else {
        NSMutableArray *constraints = [NSMutableArray new];
        for (NSLayoutConstraint *constraint in slot.home.constraints)
            if (constraint.firstItem == view || constraint.secondItem == view) [constraints addObject:constraint];
        slot.constraints = constraints;
        [NSLayoutConstraint deactivateConstraints:constraints];
        [view removeFromSuperview];
    }
    view.autoresizingMask = NSViewNotSizable;
    view.translatesAutoresizingMaskIntoConstraints = YES;
    [destination addSubview:view];
    view.frame = frame; view.hidden = NO; view.alphaValue = 1;
    slot.moving = NO;
    return slot;
}

void DPNavigationLayout(DPNavigationSlot *slot, NSRect frame) {
    if (!slot.view) return;
    slot.forcedFrame = frame;
    slot.moving = YES;
    if (!NSEqualRects(slot.view.frame, frame)) slot.view.frame = frame;
    if (slot.view.hidden != slot.forcedHidden) slot.view.hidden = slot.forcedHidden;
    if (slot.view.alphaValue != 1) slot.view.alphaValue = 1;
    slot.moving = NO;
}

void DPNavigationRestore(DPNavigationSlot *slot) {
    NSView *view = slot.view, *home = slot.home;
    if (!view) return;
    slot.moving = YES;
    DPSet(view, &DPNativeSlotKey, nil);
    [view removeFromSuperview];
    if ([home isKindOfClass:NSStackView.class]) {
        NSStackView *stack = (NSStackView *)home;
        NSUInteger count = [stack viewsInGravity:slot.gravity].count;
        [stack insertView:view atIndex:MIN(slot.index, count) inGravity:slot.gravity];
    } else if (home) {
        NSArray *siblings = home.subviews;
        if (slot.index < siblings.count) [home addSubview:view positioned:NSWindowBelow relativeTo:siblings[slot.index]];
        else [home addSubview:view];
    }
    view.autoresizingMask = slot.originalMask;
    view.translatesAutoresizingMaskIntoConstraints = slot.originalTranslates;
    view.frame = slot.originalFrame; view.hidden = slot.originalHidden; view.alphaValue = slot.originalAlpha;
    if (home && slot.constraints.count) [NSLayoutConstraint activateConstraints:slot.constraints];
    home.needsLayout = YES;
    slot.owner = nil;
    slot.view = nil;
}
