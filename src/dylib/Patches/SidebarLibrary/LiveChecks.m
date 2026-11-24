#import "Library.h"
#ifdef DPLIBRARY_DIAGNOSTICS
#import "Test/Test.h"
#import "Patches/HideToolbar/HideToolbar.h"
DPLibraryController *DPLibraryForWindow(NSWindow *window);
static NSMutableArray *DPLiveResults;
static NSArray *DPLiveScenarios;
static NSDictionary *DPLiveSaved;
static NSWindow *DPLiveWindow;
static BOOL DPLiveWithoutLibrary;
static NSArray *DPLiveToolbarState(void) {
    NSMutableArray *result = [NSMutableArray new];
    for (NSView *pane in DPFindViews(DPDiaContentPane)) {
        NSView *bar = DPSubview(pane,DPDiaToolbar);
        DPToolbarHover *hover = [DPToolbarHover forPane:pane];
        [result addObject:@{@"window":pane.window.identifier ?: @"",@"pane":NSStringFromRect(pane.frame),
            @"bar":NSStringFromRect(bar.frame),@"alpha":@(bar.alphaValue),@"hidden":@(bar.hiddenOrHasHiddenAncestor),
            @"kept":@(DPKeptInPlace(pane)),@"inPlace":@(hover.inPlace),@"inPlaceProgress":@(hover.inPlaceProgress),
            @"hoverProgress":@(hover.progress),@"hideProgress":@(DPHideToolbar.progress),
            @"withSidebar":@(DPShowToolbarWithSidebar.on),@"withTopTabs":@(DPShowToolbarWithTopTabs.on),@"onNewTab":@(DPShowToolbarOnNewTab.on)}];
    }
    return result;
}
static void DPWriteLive(BOOL complete) {
    NSDictionary *data = @{@"layout":DPTabLayout(),@"targetWindow":DPLiveWindow.identifier ?: @"",@"withoutLibrary":@(DPLiveWithoutLibrary),@"complete":@(complete),@"pid":@(NSProcessInfo.processInfo.processIdentifier),@"checks":DPLiveResults ?: @[]};
    [[NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil] writeToFile:@"/tmp/sidebar-library-live-checks.json" atomically:YES];
}
static void DPRunLibraryScenario(NSUInteger index) {
    if (index >= DPLiveScenarios.count) {
        for (NSString *key in DPLiveSaved) DPSetPatch(DPPatchNamed(key),[DPLiveSaved[key] boolValue],NO);
        DPWriteLive(YES); DPLiveScenarios = nil; DPLiveWindow = nil; return;
    }
    NSArray *scenario = DPLiveScenarios[index]; NSString *bits = scenario[1];
    for (NSUInteger i=0;i<DPPatchCount;i++) DPSetPatch(DPPatches[i], ![DPPatches[i]->key isEqual:@"onePassword"] && !(DPLiveWithoutLibrary && DPPatches[i] == &DPSidebarLibrary) && [bits characterAtIndex:i] == '1',NO);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
        NSMutableDictionary *problems = [NSMutableDictionary new];
        for (NSUInteger i=0;i<DPPatchCount;i++) {
            DPPatch *patch = DPPatches[i]; if (patch->unavailable || [patch->key isEqual:@"onePassword"]) continue;
            NSString *problem = patch->verify ? patch->verify(patch) : nil;
            if (problem) problems[patch->key] = problem;
        }
        NSView *page = DPFindView(DPLiveWindow.contentView,^BOOL(NSView *view) { return DPIsKind(view,DPDiaContentContainer) && !view.hiddenOrHasHiddenAncestor; });
        NSRect before = page.frame;
        if (DPSidebarLibrary.on) DPLibraryToggle(DPLiveWindow);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            DPLibraryController *controller = DPLibraryForWindow(DPLiveWindow);
            if (DPSidebarLibrary.on && !controller.view.superview) problems[@"libraryOpen"] = @"Library failed to mount";
            if (controller.expanded) {
                NSRect side = [page.superview convertRect:controller.sidebarHost.bounds fromView:controller.sidebarHost];
                if (NSMinX(page.frame) < NSMaxX(side)-1) problems[@"libraryPage"] = @"page overlaps expanded sidebar";
                [controller close];
            }
            // Library closes in 220ms; native toolbar options then ease for
            // another 250ms. Verify after both have finished settling.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,650*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                if (DPSidebarLibrary.on && (fabs(NSMinX(page.frame)-NSMinX(before)) > 1 || fabs(NSWidth(page.frame)-NSWidth(before)) > 1)) problems[@"libraryRestore"] = @"page frame did not restore";
                for (NSUInteger i=0;i<DPPatchCount;i++) {
                    DPPatch *patch = DPPatches[i]; if (patch->unavailable || [patch->key isEqual:@"onePassword"]) continue;
                    NSString *problem = patch->verify ? patch->verify(patch) : nil;
                    if (problem) problems[[@"afterClose." stringByAppendingString:patch->key]] = problem;
                }
                [DPLiveResults addObject:@{@"scenario":scenario[0],@"problems":problems,@"toolbar":problems.count ? DPLiveToolbarState() : @[]}];
                DPWriteLive(NO); DPRunLibraryScenario(index+1);
            });
        });
    });
}
void DPLibraryInstallLiveChecks(void) {
    DPOnLaunch(^{
        [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.library.check" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (([note.object isEqual:@"matrix"] || [note.object isEqual:@"toolbar-baseline"] || [note.object isEqual:@"repair-cases"] || [note.object isEqual:@"all-on-baseline"]) && !DPLiveScenarios) {
                DPLiveWithoutLibrary = [note.object isEqual:@"toolbar-baseline"] || [note.object isEqual:@"all-on-baseline"];
                DPLiveWindow = NSApp.keyWindow ?: NSApp.mainWindow;
                if (!DPLiveWindow) for (NSWindow *window in NSApp.windows)
                    if (window.visible && DPFindView(window.contentView,^BOOL(NSView *v) { return DPIsKind(v,DPDiaContentContainer); }) != nil) { DPLiveWindow = window; break; }
                if (!DPLiveWindow) return;
                DPLibraryDismissForWindow(DPLiveWindow);
                NSMutableDictionary *saved = [NSMutableDictionary new];
                for (NSUInteger i=0;i<DPPatchCount;i++) saved[DPPatches[i]->key] = @(DPPatches[i]->on);
                DPLiveSaved = saved; DPLiveResults = [NSMutableArray new]; DPLiveScenarios = DPScenarios();
                if ([note.object isEqual:@"all-on-baseline"]) DPLiveScenarios = [DPLiveScenarios filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSArray *scenario,NSDictionary *bindings) { return [scenario[0] isEqual:@"all on"]; }]];
                else if (DPLiveWithoutLibrary || [note.object isEqual:@"repair-cases"]) DPLiveScenarios = [DPLiveScenarios filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSArray *scenario,NSDictionary *bindings) {
                    return (!DPLiveWithoutLibrary && [scenario[0] isEqual:@"all on"]) || [@[@"pairwise 23",@"pairwise 24",@"pairwise 25",@"pairwise 26",@"pairwise 30",@"pairwise 31",@"pairwise 32"] containsObject:scenario[0]];
                }]];
                DPWriteLive(NO); DPRunLibraryScenario(0);
            } else if ([note.object hasPrefix:@"appearance="]) {
                NSString *value = [note.object substringFromIndex:11];
                NSApp.appearance = [value isEqual:@"system"] ? nil : [NSAppearance appearanceNamed:[value isEqual:@"dark"] ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
            }
        }];
    });
}
#endif
