#import "SidebarNavigation.h"

static char DPNavigationStateKey;
@implementation DPSidebarNavigationState @end
DPSidebarNavigationState *DPNavigationState(NSView *header, BOOL create) {
    DPSidebarNavigationState *state = DPGet(header, &DPNavigationStateKey);
    if (!state && create) {
        state = [DPSidebarNavigationState new];
        state.toolbarControls = [NSMutableDictionary new];
        DPSet(header, &DPNavigationStateKey, state);
    }
    return state;
}

void DPRefreshSidebarNavigation(NSView *header) {
    DPSidebarNavigationState *state = DPNavigationState(header, NO);
    BOOL active = DPSidebarNavigationControls.on && header.window && !header.hiddenOrHasHiddenAncestor &&
        DPSubview(header.superview, DPDiaSidebarFooter);
    if (!active) { DPRestoreSidebarNavigation(state); return; }
    NSView *toolbar = DPNavigationSourceToolbar(header.window);
    if (state.toolbar != toolbar) DPRestoreSidebarNavigation(state);
    if (!toolbar) return;
    state = DPNavigationState(header, YES);
    state.toolbar = toolbar;
    DPPlaceSidebarNavigation(state, header);
}

static void DPNavigationRoot_unhidden(NSView *self, SEL _cmd);
static BOOL DPRefreshingNavigation;
void DPApplySidebarNavigation(DPPatch *patch) {
    if (DPRefreshingNavigation) return;
    DPRefreshingNavigation = YES;
    @try {
        for (NSView *strip in DPFindViews(DPDiaTabStrip))
            if (!DPHorizontalNavigationAvailable(strip)) DPRestoreSidebarNavigation(DPNavigationState(strip, NO));
        for (NSView *header in DPFindViews(DPDiaSidebarHeader)) DPRefreshSidebarNavigation(header);
        for (NSView *strip in DPFindViews(DPDiaTabStrip)) DPRefreshHorizontalNavigation(strip);
    } @finally { DPRefreshingNavigation = NO; }
}

static void DPNavigationRoot_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNavigationRoot_layout, self);
    if (DPRefreshingNavigation) return;
    DPRefreshingNavigation = YES;
    @try { DPRefreshSidebarNavigation(DPSubview(self, DPDiaSidebarHeader)); }
    @finally { DPRefreshingNavigation = NO; }
}
static void DPNavigationHeader_attached(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNavigationHeader_attached, self);
    if (!self.window || !self.superview) return;
    DPHookClass(self.superview.class, @selector(layout), (IMP)DPNavigationRoot_layout);
    DPHookClass(self.superview.class, @selector(viewDidUnhide), (IMP)DPNavigationRoot_unhidden);
    self.superview.needsLayout = YES;
}
static void DPNavigationHeader_detaching(NSView *self, SEL _cmd, NSWindow *window) {
    if (window != self.window) DPRestoreSidebarNavigation(DPNavigationState(self, NO));
    DPCallOriginal(DPNavigationHeader_detaching, self, window);
}
static void DPNavigationToolbar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNavigationToolbar_layout, self);
    DPApplySidebarNavigation(NULL);
}
static void DPNavigationRoot_unhidden(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNavigationRoot_unhidden, self);
    DPApplySidebarNavigation(NULL);
}
static void DPNavigationFloating_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNavigationFloating_layout, self);
    DPApplySidebarNavigation(NULL);
}
static void DPNavigationStrip_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNavigationStrip_layout, self);
    DPApplySidebarNavigation(NULL);
}
static void DPNavigationStrip_attached(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNavigationStrip_attached, self);
    if (self.window) self.needsLayout = YES;
}
void DPInstallSidebarNavigationLayout(void) {
    DPHookClass(objc_getClass(DPDiaTabStrip), @selector(layout), (IMP)DPNavigationStrip_layout);
    DPHookClass(objc_getClass(DPDiaTabStrip), @selector(viewDidMoveToWindow), (IMP)DPNavigationStrip_attached);
    DPHookClass(objc_getClass(DPDiaTabStrip), @selector(viewWillMoveToWindow:), (IMP)DPNavigationHeader_detaching);
    DPHook(DPDiaSidebarHeader, @selector(viewDidMoveToWindow), (IMP)DPNavigationHeader_attached);
    DPHook(DPDiaSidebarHeader, @selector(viewWillMoveToWindow:), (IMP)DPNavigationHeader_detaching);
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPNavigationToolbar_layout);
    DPHookClass(objc_getClass(DPDiaFloatingSidebar), @selector(layout), (IMP)DPNavigationFloating_layout);
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        DPHookClass(header.superview.class, @selector(layout), (IMP)DPNavigationRoot_layout);
        DPHookClass(header.superview.class, @selector(viewDidUnhide), (IMP)DPNavigationRoot_unhidden);
    }
    DPApplySidebarNavigation(NULL);
}
