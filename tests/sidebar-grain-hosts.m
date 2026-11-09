#import "sidebar-grain-render.h"

static NSView *DPTestHostView(const char *name, NSRect frame) {
    Class cls = objc_getClass(name);
    if (!cls) {
        cls = objc_allocateClassPair(NSView.class, name, 0);
        objc_registerClassPair(cls);
    }
    return [[cls alloc] initWithFrame:frame];
}

static NSUInteger DPTextureCount(NSView *host) {
    NSUInteger count = 0;
    for (NSView *view in host.subviews) count += [view isKindOfClass:DPSidebarGrainView.class];
    return count;
}

void DPTestTextureHosts(void) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 500)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    NSView *sidebar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 500)];
    NSView *footer = DPTestHostView(DPDiaSidebarFooter, NSMakeRect(0, 0, 200, 40));
    NSView *strip = DPTestHostView(DPDiaTabStrip, NSMakeRect(0, 460, 600, 40));
    NSView *content = DPTestHostView(DPDiaContentContainer, NSMakeRect(0, 0, 600, 480));
    [window.contentView addSubview:content];
    [window.contentView addSubview:sidebar]; [sidebar addSubview:footer];
    [window.contentView addSubview:strip];
    DPSidebarGrain.on = YES;
    DPTrackGrainHost(sidebar); DPTrackGrainHost(strip);
    assert(DPTextureCount(sidebar) == 1 && DPTextureCount(strip) == 0);
    sidebar.hidden = YES; footer.hidden = YES;
    DPRefreshSidebarGrain();
    assert(DPTextureCount(strip) == 0); // Auto-hiding does not turn on the horizontal background.
    [footer removeFromSuperview]; DPRefreshSidebarGrain();
    assert(DPTextureCount(sidebar) == 0 && DPTextureCount(strip) == 1);
    DPSidebarGrainView *grain = (id)strip.subviews.firstObject;
    assert([grain isKindOfClass:DPSidebarGrainView.class] && ![grain hitTest:NSMakePoint(10, 10)]);
    grain.frame = NSMakeRect(80, 0, 520, 40);
    assert(NSEqualRects(grain.frame, NSMakeRect(0, 20, 600, 20)));
    content.frame = NSMakeRect(0, 0, 600, 470); DPRefreshSidebarGrain();
    assert(NSEqualRects(grain.frame, NSMakeRect(0, 10, 600, 30)));
    // Another window's vertical sidebar must not suppress this horizontal strip.
    NSWindow *other = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 500)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    [other.contentView addSubview:sidebar]; [sidebar addSubview:footer];
    DPRefreshSidebarGrain(); assert(DPTextureCount(strip) == 1);
    DPTestTextureMenu(window, strip);
    DPSidebarGrain.on = NO; DPRefreshSidebarGrain();
    assert(DPTextureCount(sidebar) == 0 && DPTextureCount(strip) == 0);
    DPTrackGrainHost(sidebar); DPTrackGrainHost(strip); // Layouts while off leave Dia's views alone.
    assert(DPTextureCount(sidebar) == 0 && DPTextureCount(strip) == 0);
    DPSidebarGrain.on = YES; DPTrackGrainHost(strip);
    assert(DPTextureCount(strip) == 1);
    DPSidebarGrain.on = NO; DPTrackGrainHost(strip);
    assert(DPTextureCount(strip) == 0);
    [strip removeFromSuperview]; [sidebar removeFromSuperview];
}
