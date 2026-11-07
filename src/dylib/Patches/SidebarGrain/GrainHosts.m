#import "SidebarGrain.h"

NSHashTable<NSView *> *DPGrainHosts;
static char DPGrainViewKey;

BOOL DPGrainHostAvailable(NSView *host) {
    if (!host.window) return NO;
    if (DPIsKind(host, DPDiaTabStrip)) {
        // A hidden, auto-hiding sidebar is still a vertical layout.
        return !DPFindView(host.window.contentView, ^BOOL(NSView *view) {
            return DPIsKind(view, DPDiaSidebarFooter);
        });
    }
    return DPSubview(host, DPDiaSidebarFooter) != nil;
}

static void DPUpdateGrainHost(NSView *host) {
    DPSidebarGrainView *grain = DPGet(host, &DPGrainViewKey);
    if (!DPSidebarGrain.on || !DPGrainHostAvailable(host)) {
        [grain removeFromSuperview];
        DPSet(host, &DPGrainViewKey, nil);
        return;
    }
    if (!grain) {
        grain = [[DPSidebarGrainView alloc] initWithFrame:host.bounds];
        grain.tracksWindowActivity = YES;
        DPSet(host, &DPGrainViewKey, grain);
    }
    if (grain.superview != host) [host addSubview:grain positioned:NSWindowBelow relativeTo:nil];
    [grain setGrainAmount:DPGrainAmount() softness:DPGrainSoftness()];
}

void DPTrackGrainHost(NSView *host) {
    if (!DPGrainHosts) DPGrainHosts = [NSHashTable weakObjectsHashTable];
    [DPGrainHosts addObject:host];
    DPRefreshSidebarGrain();
}

void DPRefreshSidebarGrain(void) {
    for (NSView *host in DPGrainHosts) DPUpdateGrainHost(host);
}

NSString *DPVerifyGrainHosts(DPPatch *patch) {
    NSMutableArray<NSView *> *hosts = [NSMutableArray new];
    for (NSView *footer in DPFindViews(DPDiaSidebarFooter))
        if (!footer.hiddenOrHasHiddenAncestor) [hosts addObject:footer.superview];
    for (NSView *strip in DPFindViews(DPDiaTabStrip))
        if (!strip.hiddenOrHasHiddenAncestor && DPGrainHostAvailable(strip)) [hosts addObject:strip];
    for (NSView *host in hosts) {
        DPSidebarGrainView *grain = DPGet(host, &DPGrainViewKey);
        BOOL installed = grain && grain.superview == host;
        if (installed != patch->on) return patch->on ? @"tab texture is missing" : @"tab texture stayed attached";
    }
    return nil;
}
