#import "PictureInPicture.h"

static char DPPiPApplyingKey, DPPiPRetryKey;

static BOOL DPPiPEnabled(void) { return DPPiPIconOnly.on || DPPiPSmallPlayPause.on || DPPiPHideDomain.on; }

static void DPRefreshPiPView(NSView *view, BOOL validate) {
    if ([DPGet(view, &DPPiPApplyingKey) boolValue]) return;
    DPSet(view, &DPPiPApplyingKey, @YES);
    if (!DPPiPEnabled()) {
        DPPiPRemoveControls((__bridge void *)view);
        DPSet(view, &DPPiPRetryKey, nil);
    } else {
        int32_t support = !validate && DPPiPHasControls((__bridge void *)view) ? 1 : DPPiPControlSupport((__bridge void *)view);
        if (support == 1) DPPiPShowControls((__bridge void *)view, DPPiPIconOnly.on, DPPiPSmallPlayPause.on, DPPiPHideDomain.on);
        else DPPiPRemoveControls((__bridge void *)view);
    }
    DPSet(view, &DPPiPApplyingKey, nil);
}

static void DPPiPRetry(NSView *view, id token, NSUInteger attempt) {
    if (DPGet(view, &DPPiPRetryKey) != token || !view.window || !DPPiPEnabled()) return;
    DPRefreshPiPView(view, YES);
    if (DPPiPHasControls((__bridge void *)view) || DPPiPControlSupport((__bridge void *)view) == 0 || attempt == 8) {
        DPSet(view, &DPPiPRetryKey, nil);
        return;
    }
    __weak NSView *weakView = view;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 10), dispatch_get_main_queue(), ^{
        NSView *current = weakView;
        if (current) DPPiPRetry(current, token, attempt + 1);
    });
}

static void DPSchedulePiP(NSView *view) {
    if (!DPPiPEnabled() || !view.window || DPGet(view, &DPPiPRetryKey) || DPPiPHasControls((__bridge void *)view)) return;
    id token = [NSObject new];
    DPSet(view, &DPPiPRetryKey, token);
    // SwiftUI initializes the native player publishers after its first layout.
    __weak NSView *weakView = view;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSView *current = weakView;
        if (current) DPPiPRetry(current, token, 0);
    });
}

static void DPPiPContent_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPiPContent_layout, self);
    DPRefreshPiPView(self, NO);
    DPSchedulePiP(self);
}

static void DPPiPContent_moved(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPiPContent_moved, self);
    DPSet(self, &DPPiPRetryKey, nil);
    if (self.window) DPSchedulePiP(self);
    else DPPiPRemoveControls((__bridge void *)self);
}

void DPApplyPiP(DPPatch *patch) {
    // Dia hides PiP while its source tab is active. Toggles must also reach that window.
    for (NSWindow *window in NSApp.windows) {
        NSView *view = DPFindView(window.contentView, ^BOOL(NSView *candidate) { return DPIsKind(candidate, DPPiPContentClass); });
        if (!view) continue;
        DPSet(view, &DPPiPRetryKey, nil);
        DPRefreshPiPView(view, YES);
        DPSchedulePiP(view);
    }
}

NSString *DPVerifyPiP(DPPatch *patch) {
    for (NSView *view in DPFindViews(DPPiPContentClass)) {
        int32_t support = DPPiPControlSupport((__bridge void *)view);
        if (support == 0) continue;
        if (DPPiPEnabled() && support < 0) return @"PiP controls changed in this Dia version";
        if (DPPiPHasControls((__bridge void *)view) != DPPiPEnabled()) return @"PiP controls did not attach";
    }
    return nil;
}

void DPInstallPiPLayout(void) {
    DPHook(DPPiPContentClass, @selector(layout), (IMP)DPPiPContent_layout);
    DPHook(DPPiPContentClass, @selector(viewDidMoveToWindow), (IMP)DPPiPContent_moved);
}
