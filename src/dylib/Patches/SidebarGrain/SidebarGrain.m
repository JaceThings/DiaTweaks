#import "SidebarGrain.h"

NSHashTable<NSView *> *DPGrainSidebars;
static char DPGrainViewKey;

static void DPUpdateSidebarGrain(NSView *sidebar) {
    DPSidebarGrainView *grain = DPGet(sidebar, &DPGrainViewKey);
    if (!DPSidebarGrain.on || !DPSubview(sidebar, DPDiaSidebarFooter)) {
        if (grain) {
            [grain removeFromSuperview];
            DPSet(sidebar, &DPGrainViewKey, nil);
        }
        return;
    }
    if (!grain) {
        grain = [[DPSidebarGrainView alloc] initWithFrame:sidebar.bounds];
        grain.tracksWindowActivity = YES;
        DPSet(sidebar, &DPGrainViewKey, grain);
    }
    if (grain.superview != sidebar) [sidebar addSubview:grain positioned:NSWindowBelow relativeTo:nil];
    [grain setGrainAmount:DPGrainAmount()
                 softness:DPGrainSoftness()];
}

void DPRefreshSidebarGrain(void) {
    for (NSView *sidebar in DPGrainSidebars) DPUpdateSidebarGrain(sidebar);
}

static void DPGrainSidebarDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPGrainSidebarDidLayout, self);
    [DPGrainSidebars addObject:self.view];
    DPUpdateSidebarGrain(self.view);
}

static void DPInstallSidebarGrain(void) {
    DPGrainSidebars = [NSHashTable weakObjectsHashTable];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskRightMouseDown handler:^NSEvent *(NSEvent *event) {
        return DPGrainRightClick(event);
    }];
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPGrainSidebarDidLayout);
}

static void DPApplySidebarGrain(DPPatch *patch) { DPRefreshGrainRows(); DPRefreshSidebarGrain(); }

static NSString *DPVerifySidebarGrain(DPPatch *patch) {
    for (NSView *footer in DPFindViews(DPDiaSidebarFooter)) {
        if (footer.hiddenOrHasHiddenAncestor) continue;
        NSView *sidebar = footer.superview;
        DPSidebarGrainView *grain = DPGet(sidebar, &DPGrainViewKey);
        BOOL installed = grain && grain.superview == sidebar;
        if (installed != patch->on) return patch->on ? @"sidebar grain is missing" : @"sidebar grain stayed attached";
    }
    return nil;
}

static NSArray<NSView *> *DPGrainRows(void) { return DPGrainRowsForWindow(nil); }

DP_PATCH(DPSidebarGrain) {
    .key = @"sidebarGrain",
    .order = 84,
    .title = @"Sidebar Grain",
    .detail = @"Add texture to the sidebar. Adjust the grain and softness.",
    .choice = @"sidebarGrainMaterial",
    .defaultChoice = @"grain",
    .symbol = @"circle.dotted",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSidebarController, DPDiaSidebarFooter),
    .install = DPInstallSidebarGrain,
    .apply = DPApplySidebarGrain,
    .verify = DPVerifySidebarGrain,
    .rows = DPGrainRows,
};
