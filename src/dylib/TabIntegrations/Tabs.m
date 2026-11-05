#import "Internal.h"

static NSArray *DPScriptWindows(void) {
    id delegate = NSApp.delegate;
    return [delegate respondsToSelector:NSSelectorFromString(@"appleScriptWindows")]
        ? [delegate valueForKey:@"appleScriptWindows"] : nil;
}

NSArray *DPIntegrationTabsInWindow(NSWindow *native) {
    for (id window in DPScriptWindows())
        if ([[window valueForKey:@"windowId"] isEqual:native.identifier]) return [window valueForKey:@"appleScriptTabs"];
    return @[];
}

id DPTabIntegrationTabForView(NSView *view) {
    if (!view.window || (!DPIsKind(view, DPDiaTabView) && !DPIsKind(view, DPDiaPinnedTab))) return nil;
    id model = [view safeSwiftValueForKey:@"viewModel"];
    NSString *identifier = [[model safeSwiftValueForKey:@"tabID"] description];
    if (!identifier.length && DPIsKind(view, DPDiaPinnedTab)) {
        id controller = [model safeSwiftValueForKey:@"delegate"];
        id itemID = [controller safeSwiftValueForKey:@"itemID"];
        identifier = [[itemID safeSwiftValueForKey:@"tab"] description];
    }
    if (!identifier.length) return nil;

    for (id window in DPScriptWindows()) {
        if (![[window valueForKey:@"windowId"] isEqual:view.window.identifier]) continue;
        for (id tab in [window valueForKey:@"appleScriptTabs"])
            if ([[tab valueForKey:@"tabId"] isEqual:identifier]) return tab;
    }
    return nil;
}

NSWindow *DPTabIntegrationTabWindow(id tab) {
    NSString *identifier = [[tab valueForKey:@"tabId"] description];
    if (!identifier.length) return nil;
    for (id window in DPScriptWindows()) {
        BOOL found = NO;
        for (id candidate in [window valueForKey:@"appleScriptTabs"])
            if ([[candidate valueForKey:@"tabId"] isEqual:identifier]) { found = YES; break; }
        if (!found) continue;
        id windowID = [window valueForKey:@"windowId"];
        for (NSWindow *native in NSApp.windows)
            if ([native.identifier isEqual:windowID]) return native;
    }
    return nil;
}
