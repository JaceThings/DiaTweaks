#import "DiaPatches.h"

static const CFTimeInterval DPAnimationDuration = 0.25;

static NSUserDefaults *DPDefaults;

NSView *DPFindView(NSView *root, BOOL (^match)(NSView *)) {
    if (!root || match(root)) return root;
    for (NSView *sub in root.subviews) {
        NSView *found = DPFindView(sub, match);
        if (found) return found;
    }
    return nil;
}

// Settings lists the patches in this order.
DPPatch *const DPPatches[] = {
    &DPEdgeToEdge,
    &DPSquareSidebarCorners,
    &DPHideToolbar,
    &DPRevealToolbarOnHover,
    &DPHideSidebarButton,
    &DPHideChatButton,
    &DPHideChatsButton,
    &DPHideRecentTabsButton,
};
const NSUInteger DPPatchCount = sizeof DPPatches / sizeof *DPPatches;

static void DPAnimate(void) {
    static NSTimer *timer;
    static CFTimeInterval start;
    static CGFloat from[sizeof DPPatches / sizeof *DPPatches];
    start = CACurrentMediaTime();
    for (NSUInteger i = 0; i < DPPatchCount; i++) from[i] = DPPatches[i]->progress;
    if (timer) return;
    timer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *t) {
        CGFloat elapsed = CACurrentMediaTime() - start, omega = 22;
        BOOL done = elapsed >= DPAnimationDuration * 2;
        CGFloat eased = done ? 1 : 1 - (1 + omega * elapsed) * exp(-omega * elapsed);
        for (NSUInteger i = 0; i < DPPatchCount; i++) DPPatches[i]->progress = from[i] + (DPPatches[i]->on - from[i]) * eased;
        for (NSUInteger i = 0; i < DPPatchCount; i++) if (DPPatches[i]->relayout) DPPatches[i]->relayout();
        if (done) {
            [t invalidate];
            timer = nil;
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

void DPSetPatch(DPPatch *patch, BOOL on) {
    if (patch->on == on) return;
    patch->on = on;
    [DPDefaults setBool:on forKey:patch->key];
    if (patch->apply) patch->apply(patch);
    else DPAnimate();
}

__attribute__((constructor)) static void DPInit(void) {
    DPDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    for (NSUInteger i = 0; i < DPPatchCount; i++) {
        DPPatch *patch = DPPatches[i];
        id value = [DPDefaults objectForKey:patch->key];
        patch->on = value ? [value boolValue] : patch->defaultOn;
        patch->progress = patch->on;
    }

    for (NSUInteger i = 0; i < DPPatchCount; i++) if (DPPatches[i]->install) DPPatches[i]->install();
    DPInstallButtons();
    DPInstallSettings();

    DPInstallUpdates();
}
