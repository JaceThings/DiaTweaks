#import "Library.h"
static BOOL DPRoutingStripContext;
static NSView *DPNativePlus(NSView *strip) {
    return DPFindView(strip,^BOOL(NSView *view) {
        return !view.hiddenOrHasHiddenAncestor &&
            ([view.identifier isEqual:@"tabStripNewTabButton"] || [view.accessibilityIdentifier isEqual:@"tabStripNewTabButton"]);
    });
}
BOOL DPLibraryHandleStripContextMenu(NSEvent *event) {
    if(!DPSidebarLibrary.on || DPRoutingStripContext ||
        (event.type!=NSEventTypeRightMouseDown && !(event.type==NSEventTypeLeftMouseDown && (event.modifierFlags&NSEventModifierFlagControl)))) return NO;
    NSWindow *window=event.window ?: [NSApp windowWithWindowNumber:event.windowNumber]; if(!window || window.attachedSheet) return NO;
    NSView *root=window.contentView;
    if(DPFindView(root,^BOOL(NSView *view){ return DPIsKind(view,DPDiaSidebarFooter) && !view.hiddenOrHasHiddenAncestor; })) return NO;
    NSView *strip=DPFindView(root,^BOOL(NSView *view){ return DPIsKind(view,DPDiaTabStrip) && !view.hiddenOrHasHiddenAncestor; });
    if(!strip) return NO;
    NSPoint point=[strip convertPoint:event.locationInWindow fromView:nil];
    NSRect header=strip.bounds; header.size.height=MIN(42,header.size.height);
    if(!NSPointInRect(point,header)) return NO;
    NSView *occupied=DPFindView(strip,^BOOL(NSView *view) {
        if(view.hiddenOrHasHiddenAncestor || view.alphaValue<.01) return NO;
        BOOL control=[view isKindOfClass:NSControl.class] || DPIsKind(view,DPDiaTabView) || DPIsKind(view,DPDiaPinnedTab) || DPIsKind(view,DPDiaTabGroupView) ||
            [NSStringFromClass(view.class) containsString:@"TabStripDockView"];
        return control && NSPointInRect([view convertPoint:event.locationInWindow fromView:nil],NSIntersectionRect(view.bounds,view.visibleRect));
    });
    if(occupied) return NO;
    NSView *plus=DPNativePlus(strip); if(!plus || plus==strip) return NO;
    // Dia creates this menu in the + button's event handler, not menuForEvent:.
    // Preserve its native profile targets, validation and layout state.
    DPRoutingStripContext=YES;
    @try { [plus rightMouseDown:event]; }
    @finally { DPRoutingStripContext=NO; }
    return YES;
}
