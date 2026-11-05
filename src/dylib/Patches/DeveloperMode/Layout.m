#import "DeveloperMode.h"

static const CGFloat DPButtonSize = 30, DPGap = 5, DPMinField = 200;
static char DPFrameKey, DPButtonsKey, DPBannerKey, DPShownKey;

static NSView *DPFieldIn(NSView *bar) {
    return DPFindView(bar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAddressField); });
}

static NSRect DPLaidOutField(NSView *field) { return [DPDiaValue(field, &DPFrameKey, @(field.frame)) rectValue]; }

static const CGFloat DPButtonsWidth = DPDevButtonCount * (DPButtonSize + DPGap);

static BOOL DPFits(NSView *field) { return !field.hidden && NSWidth(DPLaidOutField(field)) > DPButtonsWidth + DPMinField; }

static void DPRestoreField(NSView *field) {
    if (DPGet(field, &DPFrameKey)) field.frame = DPLaidOutField(field);
    DPSet(field, &DPFrameKey, nil);
}

static void DPRemoveButtons(NSView *field) {
    NSView *host = field.superview;
    [(NSArray *)DPGet(host, &DPButtonsKey) makeObjectsPerformSelector:@selector(removeFromSuperview)];
    DPSet(host, &DPButtonsKey, nil);
    DPRestoreField(field);
}

// The first button sits beside Dia's reload button and the rest between the address field and the pinned extensions;
// the field gives up the room.
void DPPlaceDevMode(NSView *bar) {
    NSView *field = DPFieldIn(bar);
    if (!field.superview) return;
    BOOL shown = DPDeveloperMode.on && DPDevModeShown(bar.window);
    DPSet(bar, &DPShownKey, @(shown));
    if (!shown) {
        DPRemoveButtons(field);
        [DPGet(bar, &DPBannerKey) removeFromSuperview];
        DPSet(bar, &DPBannerKey, nil);
        return;
    }

    NSView *banner = DPGet(bar, &DPBannerKey);
    if (!banner) {
        banner = DPMakeDevBanner(bar.bounds);
        DPSet(bar, &DPBannerKey, banner);
        [bar addSubview:banner positioned:NSWindowAbove relativeTo:bar.subviews.firstObject];
    }
    banner.needsDisplay = YES;

    NSView *host = field.superview;
    if (!DPFits(field)) return DPRemoveButtons(field);
    NSArray<DPDevButton *> *buttons = DPGet(host, &DPButtonsKey);
    if (!buttons) {
        buttons = DPMakeDevButtons();
        DPSet(host, &DPButtonsKey, buttons);
        for (DPDevButton *button in buttons) [host addSubview:button];
    }
    NSRect laidOut = DPLaidOutField(field), ours = laidOut;
    ours.origin.x += DPButtonSize + DPGap;
    ours.size.width -= DPButtonsWidth;
    DPOverride(field, &DPFrameKey, @(laidOut), @(ours));
    field.frame = ours;
    CGFloat x = NSMinX(laidOut), y = NSMidY(laidOut) - DPButtonSize / 2;
    for (DPDevButton *button in buttons) {
        button.frame = NSMakeRect(x, y, DPButtonSize, DPButtonSize);
        x = button == buttons.firstObject ? NSMaxX(ours) + DPGap : x + DPButtonSize + DPGap;
    }
}

void DPRelayoutDevMode(BOOL onlyChanged) {
    DPRefreshTabBorders();
    for (NSView *bar in DPFindViews(DPDiaToolbar)) {
        NSView *host = DPFieldIn(bar).superview;
        DPDevPanel shown = DPShownDevPanel(bar.window);
        for (DPDevButton *button in DPGet(host, &DPButtonsKey)) button.active = button.panel != DPPanelNone && button.panel == shown;
        if (onlyChanged && [DPGet(bar, &DPShownKey) boolValue] == (DPDeveloperMode.on && DPDevModeShown(bar.window))) continue;
        bar.needsLayout = YES;
        [bar layoutSubtreeIfNeeded];
        DPPlaceDevMode(bar);
    }
}

NSString *DPVerifyDevMode(DPPatch *patch) {
    for (NSView *bar in DPFindViews(DPDiaToolbar)) {
        NSView *field = DPFieldIn(bar);
        if (!field || bar.hiddenOrHasHiddenAncestor) continue;
        BOOL shown = patch->on && DPDevModeShown(bar.window);
        NSArray<DPDevButton *> *buttons = DPGet(field.superview, &DPButtonsKey);
        if ((DPGet(bar, &DPBannerKey) != nil) != shown) return shown ? @"developer banner missing" : @"developer banner stays";
        if (!shown && buttons.count) return @"developer buttons stay in the toolbar";
        if (shown && DPFits(field) && buttons.count != DPDevButtonCount) return @"developer buttons missing from the toolbar";
        for (DPDevButton *button in buttons)
            if (NSIntersectsRect(button.frame, field.frame)) return @"developer buttons overlap the address field";
    }
    return DPVerifyTabBorders(patch);
}
