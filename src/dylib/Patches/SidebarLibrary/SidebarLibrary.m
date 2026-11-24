#import "Library.h"
#import "StdPatch/Hide.h"
static char DPLibraryControllerKey;
static NSMenuItem *DPLibraryMenuItem;
static NSHashTable<DPLibraryController *> *DPLibraryControllers;
void DPLibraryInstallGestures(void);
void DPLibraryDismissRecent(NSWindow *window);
void DPLibraryCheckRecentContext(NSWindow *window);
BOOL DPLibraryHandleRecentContextMenu(NSEvent *event);
BOOL DPLibraryHandleStripContextMenu(NSEvent *event);
DPLibraryController *DPLibraryForWindow(NSWindow *window) { return DPGet(window,&DPLibraryControllerKey); }
void DPLibraryDismissForWindow(NSWindow *window) {
    DPLibraryController *controller = DPLibraryForWindow(window);
    DPLibraryDismissRecent(window);
    [controller.motion stopAnimation]; controller.motion = nil;
    DPLibraryClosePreview(controller); controller.sharingPicker = nil; DPLibraryUnmount(controller); controller.closing = NO;
    controller.previousResponder = nil;
}
static DPLibraryController *DPLibraryPrepareWindow(NSWindow *window) {
    DPLibraryController *controller = DPLibraryForWindow(window);
    if (!controller) {
        controller = [[DPLibraryController alloc] initWithWindow:window context:DPLibraryContextForWindow(window)];
        DPSet(window,&DPLibraryControllerKey,controller); [DPLibraryControllers addObject:controller];
    }
    NSString *context = DPLibraryContextForWindow(window);
    NSString *activeSpace = DPLibraryActiveSpace(window);
    if (!context && controller.expanded && (!activeSpace || [controller.spaceID isEqual:activeSpace])) context = controller.context;
    if (![controller.context isEqual:context]) {
        controller.archive = @[]; controller.files = @[]; controller.mediaFiles = @[]; controller.rows = @[];
        [controller.table reloadData]; [controller.collection reloadData]; controller.listingState = nil; controller.archiveGeneration++;
    }
    controller.context = context; return controller;
}

void DPLibraryToggle(NSWindow *window) {
    if (!DPSidebarLibrary.on || !window || window.attachedSheet) return;
    DPLibraryResetUtilityHover(window);
    DPLibraryController *controller = DPLibraryForWindow(window);
    if (controller.view.superview) {
        if (controller.closing) DPLibraryAnimate(controller,YES); else [controller close];
        return;
    }
    [DPLibraryPrepareWindow(window) show];
}
DPLibraryController *DPLibraryBeginInteraction(NSWindow *window) {
    if (!DPSidebarLibrary.on || !window || window.attachedSheet) return nil;
    DPLibraryController *existing = DPLibraryForWindow(window);
    NSString *space = DPLibraryActiveSpace(window);
    if (existing.expanded && space && existing.spaceID && ![existing.spaceID isEqual:space]) { DPLibraryDismissForWindow(window); return nil; }
    DPLibraryController *controller = DPLibraryPrepareWindow(window);
    [controller.motion stopAnimation]; controller.motion = nil; controller.closing = NO;
    controller.interacting = YES; DPLibraryDismissRecent(window);
    if (!controller.expanded) [controller showAnimated:NO];
    for (NSView *content in @[controller.searchChrome,controller.filterChrome,controller.scroll,controller.mediaScroll]) [content.layer removeAnimationForKey:@"librarySwipe"];
    if (!controller.expanded) { controller.interacting = NO; return nil; }
    DPLibraryUpdateHosts(controller); return controller;
}
static void DPApplyLibrary(DPPatch *patch) {
    if (!patch->on) for (DPLibraryController *controller in DPLibraryControllers.allObjects) [controller close];
    DPApplyHides(patch);
    DPLibraryMenuItem.hidden = !patch->on; DPLibraryRefreshFooters(); DPLibraryRefreshHorizontal();
}
static NSDictionary *DPDefaultLibraryShortcut(void) {
    return @{@"keyCode":@37,@"modifiers":@(NSEventModifierFlagCommand | NSEventModifierFlagShift),@"key":@"L"};
}
static void DPLibraryApplicationEvent(NSApplication *app,SEL _cmd,NSEvent *event) {
    if (DPSidebarLibrary.on && DPSidebarLibraryRecent.on && DPLibraryHandleRecentContextMenu(event)) return;
    if (DPLibraryHandleStripContextMenu(event)) return;
    DPCallOriginal(DPLibraryApplicationEvent,app,event);
}
static void DPInstallLibrary(void) {
#ifdef DPLIBRARY_DIAGNOSTICS
    extern void DPLibraryInstallLiveChecks(void); DPLibraryInstallLiveChecks();
    extern void DPLibraryInstallLifecycleChecks(void); DPLibraryInstallLifecycleChecks();
#endif
#ifdef DPLIBRARY_FOLLOWUP
    extern void DPLibraryInstallFollowupChecks(void); DPLibraryInstallFollowupChecks();
#endif
    DPLibraryControllers = [NSHashTable weakObjectsHashTable]; DPLibraryInstallDownloads();
    DPOnLaunch(^{
        DPLibraryInstallFooter(); DPLibraryRefreshFooters(); DPLibraryInstallHorizontal(); DPLibraryRefreshHorizontal(); DPLibraryInstallGestures();
        DPLibraryMenuItem = DPAddMenuItem(@"View",@"Sidebar Library",^{ DPLibraryToggle(NSApp.keyWindow); });
        DPLibraryMenuItem.image = DPLibraryEntryImage();
        DPLibraryMenuItem.hidden = !DPSidebarLibrary.on;
        DPHookClass(NSApp.class,@selector(sendEvent:),(IMP)DPLibraryApplicationEvent);
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
            if (!DPSidebarLibrary.on) return event;
            NSWindow *window = event.window ?: NSApp.keyWindow;
            DPLibraryController *controller = DPLibraryForWindow(window);
            if (DPShortcutMatches(event,&DPSidebarLibrary)) {
                if (!event.isARepeat) DPLibraryToggle(window); return nil;
            }
            if (event.keyCode == 53 && controller.view.superview) { [controller close]; return nil; }
            return event;
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            DPLibraryDismissForWindow(note.object);
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidResizeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            DPLibraryController *controller = DPLibraryForWindow(note.object);
            if (controller.view.superview) DPLibraryUpdateHosts(controller);
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidUpdateNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            DPLibraryCheckRecentContext(note.object);
            DPLibraryController *controller = DPLibraryForWindow(note.object);
            if (controller.expanded) {
                DPLibraryUpdateBackdrop(controller); DPLibraryUpdateChrome(controller); DPLibraryMoveSectionHighlight(controller,NO);
                if(CACurrentMediaTime()-controller.lastAccentCheck>.12 || !controller.lastAccent) {
                controller.lastAccentCheck=CACurrentMediaTime();
                NSColor *accent = DPLibraryAccentColor(note.object);
                if (![controller.lastAccent isEqual:accent]) {
                    controller.lastAccent = accent;
                    for (NSView *button in controller.rail.subviews) button.needsDisplay = YES;
                }
            }
            }
            if (controller.expanded && (controller.sidebarHost.hiddenOrHasHiddenAncestor || controller.sidebarHost.alphaValue<.01)) DPLibraryDismissForWindow(note.object);
            NSString *activeSpace = controller.expanded ? DPLibraryActiveSpace(note.object) : nil;
            if (activeSpace && controller.spaceID && ![controller.spaceID isEqual:activeSpace]) DPLibraryDismissForWindow(note.object);
        }];
    });
}
static BOOL DPReplaceLibraryCell(NSView *view) {
    if(DPIsKind(view,DPDiaLibraryCell)) return YES;
    if(DPIsKind(view,DPDiaLibraryButton)) for(NSView *parent=view.superview;parent;parent=parent.superview)
        if(DPIsKind(parent,DPDiaSidebarFooter)) return YES;
    return NO;
}
static NSString *DPVerifyLibrary(DPPatch *patch) {
    NSString *hiddenProblem = DPVerifyHides(patch); if (hiddenProblem) return hiddenProblem;
    for (DPLibraryController *controller in DPLibraryControllers.allObjects) {
        if (!patch->on && controller.view.superview) return @"Library remains visible while off";
        if (controller.view.superview && controller.view.window != controller.window) return @"Library belongs to another window";
    }
    for (NSView *footer in DPFindViews(DPDiaSidebarFooter)) {
        NSView *button = DPFindView(footer,^BOOL(NSView *view) { return [view.identifier isEqual:@"DiaTweaks.SidebarLibrary.Button"]; });
        if (patch->on && !footer.hiddenOrHasHiddenAncestor && NSWidth(footer.bounds)>160 && !button) return @"Library button is missing";
        if (!patch->on && button) return @"Library button remains while off";
        NSView *switcher = DPSubview(footer,DPDiaSpaceSwitcher);
        if (patch->on && !footer.hiddenOrHasHiddenAncestor && switcher && NSWidth(footer.bounds)>=110 && fabs(NSMidX(switcher.frame)-NSWidth(footer.bounds)/2)>1) return @"space switcher is not centered";
    }
    return DPLibraryVerifyHorizontal(patch->on);
}
DP_PATCH(DPSidebarLibrary) {
    .key = @"sidebarLibrary", .order = 85, .title = @"Sidebar Library",
    .detail = @"Browse media, downloads and archived tabs beside your current page.",
    .symbol = @"rectangle.stack", .tint = @"systemTealColor", .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSidebarFooter,DPDiaLibraryCell,"_TtC3ADK36BrowserContextDownloadDelegateBridge","ArcDownloadItem"),
    .hides = DPReplaceLibraryCell,
    .shortcut = @"sidebarLibraryShortcut", .defaultShortcut = DPDefaultLibraryShortcut,
    .install = DPInstallLibrary, .apply = DPApplyLibrary, .verify = DPVerifyLibrary,
};

static void DPApplyLibraryRecent(DPPatch *patch) {
    if (!patch->on) for (NSWindow *window in NSApp.windows) DPLibraryDismissRecent(window);
}
DP_PATCH(DPSidebarLibraryRecent) {
    .key = @"sidebarLibraryRecent", .defaultOn = YES, .order = 86,
    .title = @"Recent downloads preview", .detail = @"Preview recent downloads when hovering over the Library icon.",
    .symbol = @"arrow.down.circle", .tint = @"systemTealColor",
    .requires = @"sidebarLibrary", .apply = DPApplyLibraryRecent,
};
