#import "StdPatch/StdPatch.h"

// Dia collapses a sidebar folder when its last tab or live item goes away, and leaves it shut when new ones arrive. A
// folder that collapses without a click on its header gets one click to open it again.

extern DPPatch DPKeepFoldersOpen;

static char DPExpandedKey, DPClickedKey, DPReopenedKey;
static NSHashTable<NSView *> *DPCollapsedFolders;
static BOOL DPReopening;

// A collapsed folder turns its chevron to point right. nil until the chevron exists.
static NSNumber *DPFolderExpanded(NSView *folder) {
    Ivar ivar = class_getInstanceVariable(object_getClass(folder), "$__lazy_storage_$_chevronIconView");
    id chevron = ivar ? object_getIvar(folder, ivar) : nil;
    CALayer *layer = [chevron isKindOfClass:NSView.class] ? ((NSView *)chevron).layer : nil;
    if (!layer) return nil;
    return @(fabs(atan2(layer.transform.m12, layer.transform.m11)) < 0.1);
}

static void DPClickHeader(NSView *folder) {
    NSPoint point = [folder convertPoint:NSMakePoint(NSMidX(folder.bounds), 18) toView:nil];
    DPReopening = YES;
    for (NSEventType type = NSEventTypeLeftMouseDown; type <= NSEventTypeLeftMouseUp; type++) {
        NSEvent *event = [NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
                                        windowNumber:folder.window.windowNumber context:nil eventNumber:0 clickCount:1
                                            pressure:type == NSEventTypeLeftMouseDown];
        if (type == NSEventTypeLeftMouseDown) [folder mouseDown:event];
        else [folder mouseUp:event];
    }
    DPReopening = NO;
}

static void DPReopenFolders(void) {
    NSArray<NSView *> *folders = DPCollapsedFolders.allObjects;
    [DPCollapsedFolders removeAllObjects];
    // Several at once is a collapse-all, not a folder that emptied.
    if (!DPKeepFoldersOpen.on || folders.count != 1 || !folders[0].window || [DPFolderExpanded(folders[0]) boolValue]) return;
    DPSet(folders[0], &DPReopenedKey, @(CACurrentMediaTime()));
    DPClickHeader(folders[0]);
}

static void DPCheckFolder(NSView *folder) {
    NSNumber *expanded = DPFolderExpanded(folder);
    if (!expanded || !folder.window) return;
    BOOL collapsed = [DPGet(folder, &DPExpandedKey) boolValue] && !expanded.boolValue;
    DPSet(folder, &DPExpandedKey, expanded);
    CFTimeInterval now = CACurrentMediaTime();
    if (!collapsed || !DPKeepFoldersOpen.on || now - [DPGet(folder, &DPClickedKey) doubleValue] < 1) return;
    // Don't fight Dia if it shuts the folder again straight away.
    if (now - [DPGet(folder, &DPReopenedKey) doubleValue] < 1) return;
    if (!DPCollapsedFolders.count)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 10), dispatch_get_main_queue(), ^{ DPReopenFolders(); });
    [DPCollapsedFolders addObject:folder];
}

static void DPFolder_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPFolder_layout, self);
    DPCheckFolder(self);
}

static void DPFolder_mouse(NSView *self, SEL _cmd, NSEvent *event) {
    if (!DPReopening) DPSet(self, &DPClickedKey, @(CACurrentMediaTime()));
    DPCallOriginal(DPFolder_mouse, self, event);
}

// Dia reuses the cell for another folder, so it forgets this one's chevron.
static void DPFolder_prepareForReuse(NSView *self, SEL _cmd) {
    DPCallOriginal(DPFolder_prepareForReuse, self);
    DPSet(self, &DPExpandedKey, nil);
}

static void DPInstallKeepFoldersOpen(void) {
    DPCollapsedFolders = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaTabGroupCell, @selector(layout), (IMP)DPFolder_layout);
    DPHook(DPDiaTabGroupCell, @selector(mouseDown:), (IMP)DPFolder_mouse);
    DPHook(DPDiaTabGroupCell, @selector(mouseUp:), (IMP)DPFolder_mouse);
    DPHook(DPDiaTabGroupCell, @selector(prepareForReuse), (IMP)DPFolder_prepareForReuse);
}

DP_PATCH(DPKeepFoldersOpen) {
    .key = @"keepFoldersOpen",
    .order = 79,
    .title = @"Keep Folders Open",
    .detail = @"Stop sidebar folders collapsing on their own when they empty, so new tabs and live folder items show up.",
    .symbol = @"folder.fill",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaTabGroupCell),
    .install = DPInstallKeepFoldersOpen,
};
