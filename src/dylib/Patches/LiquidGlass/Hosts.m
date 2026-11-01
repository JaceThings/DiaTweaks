#import "LiquidGlass.h"

static NSHashTable<NSView *> *DPGlassHosts;
static char DPGlassKey;

// Inspect Dia's current view tree independently of the layout hooks, including newly opened windows.
static NSHashTable<NSView *> *DPCurrentGlassHosts(void) {
    NSHashTable *hosts = [NSHashTable weakObjectsHashTable];
    for (NSView *view in DPFindViews("NSView"))
        if (DPIsKind(view.nextResponder, DPDiaSidebarController))
            [hosts addObject:view];
    return hosts;
}

void DPApplyGlassHost(NSView *host) {
    if (!host) return;
    [DPGlassHosts addObject:host];
    DPLiquidSurface *surface = DPGet(host, &DPGlassKey);
    if (!DPLiquidGlass.on) {
        [surface removeFromSuperview];
        DPSet(host, &DPGlassKey, nil);
        return;
    }
    BOOL created = !surface;
    if (created) {
        surface = [[DPLiquidSurface alloc] initWithFrame:host.bounds];
        DPSet(host, &DPGlassKey, surface);
    }
    if (!NSEqualRects(surface.frame, host.bounds)) surface.frame = host.bounds;
    // Above the host's own opaque fill, below every existing button, tab and text field.
    if (host.subviews.firstObject != surface) [host addSubview:surface positioned:NSWindowBelow relativeTo:nil];
    if (created) [surface refresh];
}

static void DPGlass_controllerLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPGlass_controllerLayout, self);
    DPApplyGlassHost(self.view);
}

void DPRefreshGlassHosts(void) {
    for (NSView *host in DPCurrentGlassHosts().allObjects) [DPGlassHosts addObject:host];
    for (NSView *host in DPGlassHosts.allObjects) {
        DPApplyGlassHost(host);
        [(DPLiquidSurface *)DPGet(host, &DPGlassKey) refresh];
    }
}

NSString *DPVerifyGlassHosts(BOOL enabled) {
    NSHashTable *hosts = DPCurrentGlassHosts();
    for (NSView *host in DPGlassHosts.allObjects) [hosts addObject:host];
    // Top-tab windows have no sidebar to decorate.
    for (NSView *host in hosts.allObjects) {
        DPLiquidSurface *surface = DPGet(host, &DPGlassKey);
        if (enabled && !surface) return @"a glass surface is missing";
        if (!enabled && surface) return @"glass remains after switching off";
        if (!surface) continue;
        if (host.subviews.firstObject != surface) return @"glass covers foreground controls";
        if (!NSEqualRects(surface.frame, host.bounds)) return @"glass does not fit its host";
        if (!surface.accessibilityHidden) return @"decorative glass is exposed to accessibility";
        if ([surface hitTest:NSMakePoint(1, 1)]) return @"glass intercepts mouse input";
    }
    return nil;
}

void DPInstallGlassHosts(void) {
    DPGlassHosts = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPGlass_controllerLayout);
}
