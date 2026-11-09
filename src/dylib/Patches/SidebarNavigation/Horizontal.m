#import "SidebarNavigation.h"

static char DPHorizontalFrameKey;
BOOL DPHorizontalNavigationAvailable(NSView *strip) {
    if (!DPSidebarNavigationControls.on || !strip.window || strip.hiddenOrHasHiddenAncestor) return NO;
    return !DPFindView(strip.window.contentView, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaSidebarFooter);
    });
}
void DPRestoreHorizontalNavigation(DPSidebarNavigationState *state) {
    for (NSView *view in state.shiftedViews.allObjects) {
        NSRect native = [DPDiaValue(view, &DPHorizontalFrameKey, @(view.frame)) rectValue];
        DPSet(view, &DPHorizontalFrameKey, nil);
        view.frame = native;
    }
    [state.shiftedViews removeAllObjects];
}
void DPRefreshHorizontalNavigation(NSView *strip) {
    DPSidebarNavigationState *state = DPNavigationState(strip, NO);
    if (!DPHorizontalNavigationAvailable(strip) || !DPSidebarNavigation.on) {
        DPRestoreSidebarNavigation(state); return;
    }
    NSView *toolbar = DPNavigationSourceToolbar(strip.window);
    if (state.toolbar != toolbar) DPRestoreSidebarNavigation(state);
    if (!toolbar) return;
    state = DPNavigationState(strip, YES); state.toolbar = toolbar;
    DPRestoreHorizontalNavigation(state);
    NSView *traffic = DPFindView(strip, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaTrafficLights); });
    NSRect lights = traffic && !traffic.hiddenOrHasHiddenAncestor ? [strip convertRect:traffic.bounds fromView:traffic] : NSZeroRect;
    CGFloat start = NSIsEmptyRect(lights) ? 14 : NSMaxX(lights) + 8;
    NSArray *labels = @[@[@"Go back"], @[@"Go forward"], @[@"Reload this page", @"Stop loading this page"]];
    NSUInteger slots = (NSUInteger)floor(MAX(0, NSWidth(strip.bounds) - start - 128) / 28);
    if (!slots) { DPRestoreSidebarNavigation(state); return; }
    CGFloat y = NSIsEmptyRect(lights) ? 7 : round(NSMidY(lights)-14);
    BOOL hasToggle = DPPlaceSidebarToggle(state, strip, NSMakeRect(start, y, 28, 28));
    NSUInteger capacity = MIN(3, slots - hasToggle);
    CGFloat shift = (capacity + hasToggle) * 28 + 8;
    if (hasToggle) start += 28;
    state.shiftedViews = state.shiftedViews ?: [NSHashTable weakObjectsHashTable];
    // The native dock and the tab container share their original relative spacing.
    for (NSView *child in strip.subviews) {
        if (child == traffic || (traffic && [traffic isDescendantOf:child]) || DPNavigationSlotFor(child).owner == strip || child.hidden) continue;
        NSRect native = child.frame, frame = native;
        if (NSWidth(native) >= NSWidth(strip.bounds)-1) {
            frame.origin.x += shift; frame.size.width = MAX(0, frame.size.width-shift);
        } else if (NSMinX(native) >= NSMaxX(lights)) frame.origin.x += shift;
        else continue;
        DPOverride(child, &DPHorizontalFrameKey, @(native), @(frame));
        [state.shiftedViews addObject:child]; child.frame = frame;
    }
    for (NSUInteger i=0; i<labels.count; i++) {
        NSString *key = labels[i][0];
        DPNavigationSlot *slot = state.toolbarControls[key];
        if (i >= capacity) { DPNavigationRestore(slot); [state.toolbarControls removeObjectForKey:key]; continue; }
        if (!slot.view) {
            NSView *button = DPFindView(toolbar, ^BOOL(NSView *v) { return [labels[i] containsObject:v.accessibilityLabel ?: @""]; });
            slot = DPNavigationAttach(button, strip, strip, NSMakeRect(start+i*28,y,28,28));
        }
        DPNavigationLayout(slot, NSMakeRect(start+i*28,y,28,28));
        state.toolbarControls[key] = slot;
    }
}
