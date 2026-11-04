#import "KeepSavedTabs.h"

@interface NSObject (DPSwiftFields)
- (id)safeSwiftValueForKey:(NSString *)key;
@end

NSView *DPSavedEnclosing(NSView *view, Class cls) {
    while (view && !(cls && [view isKindOfClass:cls])) view = view.superview;
    return view;
}

BOOL DPSavedIsSaved(NSView *tab) {
    NSView *list = DPSavedEnclosing(tab, NSCollectionView.class);
    NSView *separator = DPSubview(list, DPDiaTabListSeparator);
    if (!separator) return NO;
    NSRect frame = [list convertRect:tab.bounds fromView:tab];
    return list.isFlipped ? NSMaxY(frame) <= NSMinY(separator.frame) + 0.5 : NSMinY(frame) >= NSMaxY(separator.frame) - 0.5;
}

static id DPSwiftField(id object, NSString *key) {
    id value = [object respondsToSelector:@selector(safeSwiftValueForKey:)] ? [object safeSwiftValueForKey:key] : nil;
    return value == NSNull.null ? nil : value;
}

// Dia fills live folders (GitHub pull requests and the like) itself, so ✕ on one of their items loses nothing you saved.
static BOOL DPSavedIsLiveItem(NSView *tab) {
    NSDictionary *controllers = DPSwiftField(DPSwiftField(DPSwiftField(tab, @"viewModel"), @"delegate"), @"contentControllers");
    if (![controllers isKindOfClass:NSDictionary.class]) return NO;
    for (id controller in controllers.allValues) if (DPSwiftField(controller, @"currentlyRenderedLiveItem")) return YES;
    return NO;
}

BOOL DPSavedKeepsTab(NSView *tab) {
    return DPSavedIsSaved(tab) && !DPSavedIsLiveItem(tab);
}

BOOL DPSavedIsSelected(NSView *tab) {
    return [tab.accessibilityValue integerValue] == 1;
}

// The ID is a Swift String holding a UUID. How it's laid out in memory varies from tab to tab, so it's read through the field.
NSString *DPSavedTabID(NSView *tab) {
    Ivar ivar = class_getInstanceVariable(object_getClass(tab), "viewModel");
    id viewModel = ivar ? object_getIvar(tab, ivar) : nil;
    NSString *uuid = [DPSwiftField(viewModel, @"tabID") description];
    return uuid && [[NSUUID alloc] initWithUUIDString:uuid] ? uuid : nil;
}

NSArray<NSView *> *DPSavedTabsIn(NSView *root) {
    NSMutableArray<NSView *> *tabs = [NSMutableArray new];
    Class cls = objc_getClass(DPDiaTabView);
    DPFindView(root, ^BOOL(NSView *view) {
        if (cls && [view isKindOfClass:cls] && !view.hiddenOrHasHiddenAncestor) [tabs addObject:view];
        return NO;
    });
    [tabs sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        return [@(NSMaxY([b convertRect:b.bounds toView:nil])) compare:@(NSMaxY([a convertRect:a.bounds toView:nil]))];
    }];
    return tabs;
}

NSView *DPSavedTabWithID(NSView *root, NSString *tabID) {
    for (NSView *tab in DPSavedTabsIn(root)) if ([DPSavedTabID(tab) isEqualToString:tabID]) return tab;
    return nil;
}

NSButton *DPSavedCloseButton(NSView *tab) {
    return (NSButton *)DPFindView(tab, ^BOOL(NSView *view) { return [view isKindOfClass:NSButton.class] && DPHasLabel(view, @"Close tab"); });
}

NSUInteger DPSavedPanes(NSWindow *window) {
    __block NSUInteger panes = 0;
    Class cls = objc_getClass(DPDiaContentPane);
    DPFindView(window.contentView, ^BOOL(NSView *view) {
        if (cls && [view isKindOfClass:cls] && !view.hiddenOrHasHiddenAncestor) panes++;
        return NO;
    });
    return panes;
}

BOOL DPSavedSelecting;

void DPSavedSelect(NSView *tab) {
    NSPoint point = [tab convertPoint:NSMakePoint(NSMidX(tab.bounds) - 20, NSMidY(tab.bounds)) toView:nil];
    DPSavedSelecting = YES;
    for (NSEventType type = NSEventTypeLeftMouseDown; type <= NSEventTypeLeftMouseUp; type++)
        [tab.window sendEvent:[NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
                                             windowNumber:tab.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:type == NSEventTypeLeftMouseDown]];
    DPSavedSelecting = NO;
}

void DPSavedClickHeader(NSView *folder) {
    NSPoint header = [folder convertPoint:NSMakePoint(NSMidX(folder.bounds), 18) toView:nil];
    for (NSEventType type = NSEventTypeLeftMouseDown; type <= NSEventTypeLeftMouseUp; type++) {
        NSEvent *event = [NSEvent mouseEventWithType:type location:header modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
                                        windowNumber:folder.window.windowNumber context:nil eventNumber:0 clickCount:1
                                            pressure:type == NSEventTypeLeftMouseDown];
        if (type == NSEventTypeLeftMouseDown) [folder mouseDown:event];
        else [folder mouseUp:event];
    }
}
