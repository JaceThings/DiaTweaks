#import "SidebarToolbar.h"

static char DPFieldKey, DPFadedKey, DPThemedKey, DPStyledKey;

NSView *DPBarAddress(NSView *bar) {
    return DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressBar); });
}

NSTextView *DPBarText(NSView *bar) {
    return (NSTextView *)DPFindView(DPBarAddress(bar), ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressText); });
}

BOOL DPIsSidebarToggle(NSView *item) {
    return DPHasLabel(item, @"Toggle sidebar");
}

static BOOL DPIsNavigation(NSView *item) {
    return [NSStringFromClass(item.class) hasPrefix:@DPDiaNavigationButton] || DPIsSidebarToggle(item);
}

// Navigation buttons join the header's controls; everything else gets a row of its own.
NSArray<NSView *> *DPBarItems(NSView *bar, BOOL navigation) {
    NSView *address = DPBarAddress(bar);
    NSMutableArray<NSView *> *items = [NSMutableArray new];
    for (NSView *item in address.superview.subviews)
        if (item != address && !item.hidden && !NSIsEmptyRect(item.frame) && DPIsNavigation(item) == navigation) [items addObject:item];
    [items sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) { return [@(NSMinX(a.frame)) compare:@(NSMinX(b.frame))]; }];
    return items;
}

BOOL DPIsFaded(NSView *item) {
    return [DPGet(item, &DPFadedKey) boolValue];
}

static void DPFade(NSView *item, BOOL faded) {
    if (DPIsFaded(item) == faded && item.alphaValue == !faded) return;
    DPSet(item, &DPFadedKey, faded ? @YES : nil);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        item.animator.alphaValue = !faded;
    }];
}

// Bolder than the buttons beside it, in every tab's bar alike, docked or not.
static void DPStyleToggle(NSView *bar, BOOL on) {
    NSImageSymbolConfiguration *bold = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightSemibold];
    // Not only the laid-out items: a new bar's toggle has no frame yet the first time through.
    for (NSView *item in DPBarAddress(bar).superview.subviews) {
        if (!DPIsSidebarToggle(item)) continue;
        for (NSImageView *image in item.subviews) {
            if (![image isKindOfClass:NSImageView.class]) continue;
            // The weight is drawn into the image itself: a configuration set on the view isn't always redrawn.
            NSArray *styled = DPGet(image, &DPStyledKey);
            BOOL current = styled && image.image == styled.lastObject;
            if (on && !current && image.image) {
                NSImage *original = image.image, *bolded = [original imageWithSymbolConfiguration:bold];
                if (!bolded) continue;
                DPSet(image, &DPStyledKey, @[original, bolded]);
                image.image = bolded;
            } else if (!on && styled) {
                if (current) image.image = styled.firstObject;
                DPSet(image, &DPStyledKey, nil);
            }
        }
    }
}

// Back where Dia had it, out of the sidebar.
static void DPRestoreBar(NSView *bar, NSView *row) {
    NSView *address = DPBarAddress(bar);
    if (address) DPArrangeAddress(address, NO);
    for (NSView *item in row.subviews) if (DPIsFaded(item)) DPFade(item, NO);
}

void DPArrangeBar(NSView *bar) {
    BOOL docked = DPIsDocked(bar);
    DPStyleToggle(bar, DPDocking());
    for (NSView *item in DPBarAddress(bar).superview.subviews)
        if (DPIsNavigation(item) && (docked || DPGet(item, &DPThemedKey))) {
            DPSet(item, &DPThemedKey, @YES);
            DPThemeIcons(item);
        }
    for (NSView *sub in bar.subviews) if (DPIsKind(sub, DPDiaToolbarBackground)) sub.hidden = docked;
    NSView *field = DPGet(bar, &DPFieldKey), *row = DPBarAddress(bar).superview;
    field.hidden = !docked;
    DPArrangeExtensions(bar, row, docked);
    if (!docked) return DPRestoreBar(bar, row);
    if (!row) return;
    if (!field) {
        field = [DPFieldView new];
        DPSet(bar, &DPFieldKey, field);
        [bar addSubview:field positioned:NSWindowBelow relativeTo:row];
    }
    NSView *sidebar = bar.superview;
    if (!NSEqualRects(bar.frame, DPDockFrame(sidebar, bar))) sidebar.needsLayout = YES;
    DPPlaceDocked(bar, row, field);
}

NSView *DPAddressField(NSView *bar) {
    return DPGet(bar, &DPFieldKey);
}

void DPFadeUnlessFits(NSView *item, BOOL fits) {
    DPFade(item, !fits);
}
