#import "Patches/CommandBar/CommandBarOverlay.h"
#import "Patches/CommandBar/Tabs.h"
#import "Patches/CommandBar/HideTab.h"

BOOL DPInTabLayout(NSView *view) {
    for (; view; view = view.superview) {
        const char *name = object_getClassName(view);
        if (strstr(name, "TabSidebar") || strstr(name, "TabStrip")) return YES;
    }
    return NO;
}

NSEvent *DPTabLayoutMouseDown(DPCommandBarOverlay *overlay, NSEvent *event) {
    if ([overlay.panel hitTest:[overlay convertPoint:event.locationInWindow fromView:nil]]) return event;
    NSView *under = [overlay viewUnder:[overlay.superview convertPoint:event.locationInWindow fromView:nil]];
    NSView *button = under, *tabView = under;
    Class tabCls = objc_getClass(DPDiaTabView);
    while (button && !DPIsNewTabButton(button)) button = button.superview;
    while (tabView && !(tabCls && [tabView isKindOfClass:tabCls])) tabView = tabView.superview;
    if (!DPInTabLayout(under) || (button && DPHidesTab(DPTabID(overlay.openedTab)))) return event;
    // Clicking the current tab dismisses the bar like any other outside click (#583).
    // Swallow it so Dia doesn't take a single click as focus or a double click as rename.
    BOOL onFront = tabView && overlay.returnTab && [DPStripTabID(tabView) isEqual:DPTabID(overlay.returnTab)];
    NSWindow *window = overlay.host;
    NSString *tab = DPTabID(overlay.openedTab), *front = DPActiveTabID(window);
    DPCancelCommandBar(overlay);
    if (onFront) return nil;  // Not on to Dia, which would take it as a double click and rename the tab.
    NSView *favorite = under;
    while (favorite && !strstr(object_getClassName(favorite), "TabDockItemView")) favorite = favorite.superview;
    if (event.type == NSEventTypeLeftMouseDown && (tabView || favorite)) DPStandInWhileSwitching(window, tab, front);
    return event;
}

// Front-tab clicks now dismiss the bar, so there is nothing to refocus.
void DPTabLayoutMouseUp(DPCommandBarOverlay *overlay) {
    (void)overlay;
}
