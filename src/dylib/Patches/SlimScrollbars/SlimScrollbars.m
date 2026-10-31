#import "StdPatch/StdPatch.h"

extern DPPatch DPSlimScrollbars;

// Dia's native views and its web pages both follow AppKit's preferred style, so overlay
// scrollbars float over content without a gutter even with a mouse connected.
static NSScrollerStyle DPScroller_preferredScrollerStyle(id self, SEL _cmd) {
    return DPSlimScrollbars.on ? NSScrollerStyleOverlay : DPCallOriginal(DPScroller_preferredScrollerStyle, self);
}

static void DPInstallSlimScrollbars(void) {
    DPHookClass(object_getClass(NSScroller.class), @selector(preferredScrollerStyle), (IMP)DPScroller_preferredScrollerStyle);
}

static void DPApplySlimScrollbars(DPPatch *patch) {
    [NSNotificationCenter.defaultCenter postNotificationName:NSPreferredScrollerStyleDidChangeNotification object:nil];
}

static NSString *DPVerifySlimScrollbars(DPPatch *patch) {
    return patch->on && NSScroller.preferredScrollerStyle != NSScrollerStyleOverlay ? @"scrollbars still take a gutter" : nil;
}

DP_PATCH(DPSlimScrollbars) {
    .key = @"overlayScrollbars",
    .order = 90,
    .title = @"Slim scrollbars",
    .detail = @"Use thin scrollbars that float over pages instead of taking up a gutter.",
    .symbol = @"scroll",
    .tint = @"systemGreenColor",
    .install = DPInstallSlimScrollbars,
    .apply = DPApplySlimScrollbars,
    .verify = DPVerifySlimScrollbars,
};
