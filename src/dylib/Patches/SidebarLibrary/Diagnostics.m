#import "Library.h"
#ifdef DPLIBRARY_DIAGNOSTICS
NSDictionary *DPLibraryStructure(id object);
NSDictionary *DPLibraryStateShape(id object);
void DPLibraryInspectSidebar(NSWindow *window) {
    [[NSJSONSerialization dataWithJSONObject:DPLibraryStateShape(window) options:NSJSONWritingPrettyPrinted error:nil] writeToFile:@"/tmp/sidebar-library-state-shape.json" atomically:YES];
    NSMutableArray *objects = [NSMutableArray arrayWithObjects:window,window.windowController ?: NSNull.null,window.contentViewController ?: NSNull.null,nil];
    NSView *header = DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v,DPDiaSidebarHeader); });
    for (NSResponder *view = header; view && objects.count < 12; view = view.nextResponder) [objects addObject:view];
    id delegate = NSApp.delegate;
    if ([delegate respondsToSelector:NSSelectorFromString(@"appleScriptWindows")]) {
        for (id facade in [delegate valueForKey:@"appleScriptWindows"]) {
            [objects addObject:facade];
            if ([facade respondsToSelector:NSSelectorFromString(@"activeTab")]) { id tab = [facade valueForKey:@"activeTab"]; if (tab) [objects addObject:tab]; }
            if ([facade respondsToSelector:NSSelectorFromString(@"activeProfile")]) {
                id profile = [facade valueForKey:@"activeProfile"]; if (profile) [objects addObject:profile];
            }
        }
    }
    NSView *tint = DPFindView(window.contentView.superview,^BOOL(NSView *v) { return DPIsKind(v,DPDiaWindowTint); });
    if (tint) { [objects addObject:tint]; [objects addObjectsFromArray:tint.subviews]; }
    NSArray *keys = @[@"sidebarContainerController",@"sidebarResizeTransitionSession",@"tabSidebarResizeState",@"viewModel",@"stateSubject",@"currentValue",@"value",@"state",@"activeSpace",@"activeBrowser",@"context"];
    for (NSUInteger round=0;round<3;round++) for (id object in objects.copy) for (NSString *key in keys) {
        id child = DPSwiftValue(object,key); if (child && child != NSNull.null && ![objects containsObject:child]) [objects addObject:child];
    }
    NSMutableArray *result = [NSMutableArray new];
    for (id object in objects) {
        unsigned count = 0; Method *methods = class_copyMethodList([object class],&count);
        NSMutableArray *names = [NSMutableArray new];
        for (unsigned i=0;i<count;i++) [names addObject:NSStringFromSelector(method_getName(methods[i]))]; free(methods);
        [result addObject:@{@"class":NSStringFromClass([object class]),@"fields":DPLibraryStructure(object),@"methods":names,@"frame":[object isKindOfClass:NSView.class] ? NSStringFromRect([(NSView *)object frame]) : @""}];
    }
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:@"/tmp/sidebar-library-structure.json" atomically:YES];
}
#endif
