#import "SidebarGrain.h"

@interface DPGrainMenu : NSObject
@property (weak) NSView *sidebar;
@property NSPoint anchor;
- (void)editGrain:(NSMenuItem *)item;
@end

@implementation DPGrainMenu
- (void)editGrain:(NSMenuItem *)item {
    NSView *sidebar = self.sidebar;
    if (!sidebar.window) return;
    static NSPopover *popover;
    [popover close];
    popover = [NSPopover new];
    popover.behavior = NSPopoverBehaviorTransient;
    NSViewController *controller = [NSViewController new];
    NSView *row = DPGrainRowsForWindow(sidebar.window).firstObject;
    controller.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 238)];
    [controller.view addSubview:row];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:controller.view.topAnchor constant:14],
        [row.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor constant:-14],
    ]];
    popover.contentViewController = controller;
    popover.contentSize = controller.view.frame.size;
    BOOL horizontal = DPIsKind(sidebar, DPDiaTabStrip);
    NSRect anchor = horizontal ? NSMakeRect(self.anchor.x, self.anchor.y, 1, 1) :
        NSMakeRect(NSMaxX(sidebar.bounds) - 1, self.anchor.y, 1, 1);
    NSRectEdge edge = horizontal ? (sidebar.isFlipped ? NSRectEdgeMaxY : NSRectEdgeMinY) : NSRectEdgeMaxX;
    [popover showRelativeToRect:anchor ofView:sidebar preferredEdge:edge];
}
@end

NSEvent *DPGrainRightClick(NSEvent *event) {
    if (!DPSidebarGrain.on || !event.window) return event;
    for (NSView *sidebar in DPGrainHosts) {
        if (sidebar.window != event.window || sidebar.hiddenOrHasHiddenAncestor ||
            !DPGrainHostAvailable(sidebar)) continue;
        NSPoint point = [sidebar convertPoint:event.locationInWindow fromView:nil];
        if (!NSPointInRect(point, DPGrainHostBounds(sidebar))) continue;
        NSView *hit = [sidebar hitTest:[sidebar convertPoint:point toView:sidebar.superview]];
        NSCollectionView *collection = nil;
        for (NSView *view = hit; view && view != sidebar; view = view.superview) {
            if ([view isKindOfClass:NSCollectionView.class]) {
                collection = (NSCollectionView *)view;
                break;
            }
        }
        BOOL horizontal = DPIsKind(sidebar, DPDiaTabStrip);
        if (horizontal && ([hit isKindOfClass:NSControl.class] ||
            [hit.accessibilityRole isEqual:NSAccessibilityButtonRole] ||
            [hit.accessibilityRole isEqual:NSAccessibilityRadioButtonRole])) return event;
        if (!collection && hit != sidebar && (!horizontal || !hit ||
            NSHeight([sidebar convertRect:hit.bounds fromView:hit]) < NSHeight(sidebar.bounds) - 0.5)) return event;
        if ([collection indexPathForItemAtPoint:[collection convertPoint:event.locationInWindow fromView:nil]]) return event;
        NSMenu *menu = nil;
        if (horizontal) {
            for (NSView *view = hit; view && view != sidebar.superview && !menu; view = view.superview)
                menu = [view menuForEvent:event];
            if (!menu || [menu indexOfItemWithTitle:@"Show Tabs in Sidebar"] < 0) return event;
        } else menu = [collection menuForEvent:event] ?: [sidebar menuForEvent:event] ?: [NSMenu new];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Edit Sidebar Grain…" action:@selector(editGrain:) keyEquivalent:@""];
        DPGrainMenu *target = [DPGrainMenu new];
        target.sidebar = sidebar;
        target.anchor = point;
        item.target = target;
        NSInteger index = [menu indexOfItemWithTitle:@"Auto-Hide Tabs"];
        if (index >= 0) {
            NSMenuItem *autoHide = [menu itemAtIndex:index];
            NSImage *sidebarIcon = [menu itemWithTitle:@"Show Tabs in Sidebar"].image;
            item.indentationLevel = autoHide.indentationLevel;
            NSSize iconSize = autoHide.image ? autoHide.image.size : sidebarIcon.size;
            if (iconSize.width > 0) item.image = [[NSImage alloc] initWithSize:iconSize];
        }
        if (index < 0) index = [menu indexOfItemWithTitle:@"Show Tabs in Sidebar"];
        if (index >= 0) index++;
        else {
            index = [menu indexOfItemWithTitle:@"Close All Tabs"];
            if (index < 0) index = 0;
        }
        [menu insertItem:item atIndex:index];
        [NSMenu popUpContextMenu:menu withEvent:event forView:sidebar];
        [menu removeItem:item];
        return nil;
    }
    return event;
}
