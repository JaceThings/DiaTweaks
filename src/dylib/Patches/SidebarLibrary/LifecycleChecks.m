#import "Library.h"
#ifdef DPLIBRARY_DIAGNOSTICS
DPLibraryController *DPLibraryForWindow(NSWindow *window);
static BOOL DPLifecycleRunning;
static void DPWriteLifecycle(NSUInteger count,BOOL complete) {
    NSDictionary *report = @{@"pid":@(NSProcessInfo.processInfo.processIdentifier),@"completed":@(count),@"complete":@(complete)};
    [[NSJSONSerialization dataWithJSONObject:report options:0 error:nil] writeToFile:@"/tmp/sidebar-library-lifecycle-live.json" atomically:YES];
}
static NSButton *DPLifecycleSection(DPLibraryController *controller,NSString *title) {
    for (NSButton *button in controller.rail.subviews) if ([button.identifier isEqual:@"category"] && [button.accessibilityLabel isEqual:title]) return button;
    return nil;
}
static void DPRunLifecycle(NSWindow *window,NSUInteger count) {
    if (count == 20) { DPWriteLifecycle(count,YES); DPLifecycleRunning = NO; return; }
    DPLibraryToggle(window);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,350*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        DPLibraryController *controller = DPLibraryForWindow(window);
        [controller chooseSection:DPLifecycleSection(controller,@"Media")]; [controller.collection layoutSubtreeIfNeeded];
        [controller chooseSection:DPLifecycleSection(controller,@"Downloads")];
        controller.search.stringValue = @"no matching library fixture"; [controller reload];
        [controller.collection layoutSubtreeIfNeeded];
        [controller chooseSection:DPLifecycleSection(controller,@"Archived Tabs")]; [controller.table layoutSubtreeIfNeeded];
        [controller chooseSection:DPLifecycleSection(controller,@"Media")]; [controller close];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,350*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            DPWriteLifecycle(count+1,NO); DPRunLifecycle(window,count+1);
        });
    });
}
void DPLibraryInstallLifecycleChecks(void) {
    DPOnLaunch(^{
        [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.library.lifecycle" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (DPLifecycleRunning || !DPSidebarLibrary.on) return;
            NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
            if (!window) for (NSWindow *candidate in NSApp.windows)
                if (DPFindView(candidate.contentView,^BOOL(NSView *v) { return DPIsKind(v,DPDiaContentContainer); }) != nil) { window = candidate; break; }
            if (!window) return;
            DPLibraryDismissForWindow(window); DPLifecycleRunning = YES; DPWriteLifecycle(0,NO); DPRunLifecycle(window,0);
        }];
    });
}
#endif
