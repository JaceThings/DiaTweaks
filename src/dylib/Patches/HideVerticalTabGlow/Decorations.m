#import "HideVerticalTabGlow.h"

static char DPDiaHiddenKey;
static NSHashTable *DPDecorations;
static NSMapTable *DPDecorationOwners;

id DPTabDecoration(NSView *shape, const char *name) {
    void **slot = DPIvar(shape, name);
    id part = slot ? (__bridge id)*slot : nil;
    return [part isKindOfClass:CALayer.class] || [part isKindOfClass:NSView.class] ? part : nil;
}

BOOL DPHasTabOverride(id part) { return DPGet(part, &DPDiaHiddenKey) != nil; }

static void DPDecoration_setHidden(id self, SEL _cmd, BOOL hidden) {
    if (DPHasTabOverride(self)) {
        DPSet(self, &DPDiaHiddenKey, @(hidden));
        hidden |= DPHideVerticalTabGlow.on && DPIsVerticalTab([DPDecorationOwners objectForKey:self]);
    }
    DPCallOriginal(DPDecoration_setHidden, self, hidden);
}

void DPRestoreTabDecoration(id part) {
    NSNumber *saved = DPGet(part, &DPDiaHiddenKey);
    if (!saved) return;
    DPSet(part, &DPDiaHiddenKey, nil);
    [DPDecorationOwners removeObjectForKey:part];
    [DPDecorations removeObject:part];
    [part setHidden:saved.boolValue];
}

void DPHideTabDecoration(id part, NSView *shape) {
    if (!part) return;
    if (!DPHideVerticalTabGlow.on || !DPIsVerticalTab(shape)) return DPRestoreTabDecoration(part);
    NSNumber *dia = DPGet(part, &DPDiaHiddenKey);
    if (!dia) {
        DPSet(part, &DPDiaHiddenKey, dia = @([part isHidden]));
        [DPDecorations addObject:part];
        DPHookClass([part class], @selector(setHidden:), (IMP)DPDecoration_setHidden);
    }
    [DPDecorationOwners setObject:shape forKey:part];
    [part setHidden:dia.boolValue];
}

void DPRestoreTabDecorations(void) {
    for (id part in DPDecorations.allObjects) DPRestoreTabDecoration(part);
}

void DPInstallTabDecorations(void) {
    DPDecorations = [NSHashTable weakObjectsHashTable];
    DPDecorationOwners = [NSMapTable weakToWeakObjectsMapTable];
}
