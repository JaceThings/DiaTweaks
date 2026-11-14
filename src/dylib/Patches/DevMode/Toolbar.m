#import "DevMode.h"

static char DPButtonsKey;

static BOOL DPIsAddressButton(NSView *view) {
    return DPHasLabel(view, @"Bookmark this page") || DPHasLabel(view, @"Site menu");
}

static NSStackView *DPAddressButtons(NSView *bar) {
    return (NSStackView *)DPFindView(bar, ^BOOL(NSView *view) {
        if (![view isKindOfClass:NSStackView.class]) return NO;
        for (NSView *item in ((NSStackView *)view).arrangedSubviews)
            if (DPIsAddressButton(item)) return YES;
        return NO;
    });
}

static NSString *DPHostOfBar(NSView *bar) {
    NSView *pane = DPPaneAbove(bar);
    return pane ? DPHostOf(DPPageIn(pane)) : nil;
}

static BOOL DPWantsButtons(NSView *bar) { return DPDevMode.on && DPDevModeOn(DPHostOfBar(bar)); }

static void DPUpdateToolbar(NSView *bar) {
    NSStackView *stack = DPAddressButtons(bar);
    NSView *buttons = DPGet(bar, &DPButtonsKey);
    BOOL wanted = DPWantsButtons(bar);
    DPShowStripes(bar, wanted);
    if (!stack || (!buttons && !wanted)) return;
    if (!buttons) DPSet(bar, &DPButtonsKey, buttons = DPMakeDevButtons());
    if (buttons.superview != stack) {
        NSUInteger index = [stack.arrangedSubviews indexOfObjectPassingTest:^BOOL(NSView *view, NSUInteger i, BOOL *stop) { return DPIsAddressButton(view); }];
        [stack insertArrangedSubview:buttons atIndex:index == NSNotFound ? stack.arrangedSubviews.count : index];
    }
    if (buttons.hidden == wanted) buttons.hidden = !wanted;
}

void DPUpdateToolbars(void) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) DPUpdateToolbar(bar);
    DPUpdateTabOutlines();
}

static void DPToolbar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPToolbar_layout, self);
    DPUpdateToolbar(self);
}

void DPInstallToolbar(void) {
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPToolbar_layout);
    [NSNotificationCenter.defaultCenter addObserverForName:DPDevModeSitesDidChange object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        DPUpdateToolbars();
    }];
}

NSString *DPVerifyToolbars(DPPatch *patch) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) {
        if (!DPPageIn(DPPaneAbove(bar)) || !DPAddressButtons(bar)) continue;
        NSView *buttons = DPGet(bar, &DPButtonsKey);
        BOOL shown = buttons.superview && !buttons.hidden, wanted = DPWantsButtons(bar);
        if (shown != wanted) return wanted ? @"a page in Developer Mode has no developer buttons" : @"developer buttons outside Developer Mode";
    }
    return nil;
}
