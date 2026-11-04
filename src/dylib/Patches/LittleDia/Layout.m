#import "Bar.h"

// Dia lays out its popup bar around its address view, so this follows that view's frame to lay out Little Dia's bar.
static char DPDiaOriginKey, DPDiaSizeKey;

static BOOL DPInPopupBar(NSView *view) {
    for (NSView *each = view.superview; each; each = each.superview)
        if (DPIsKind(each, DPDiaPopupBar)) return YES;
    return NO;
}

static BOOL DPShowsBar(NSView *title) { return DPLittleDia.on && DPInPopupBar(title) && DPIsLittleDiaWindow(title.window); }

// Where the address goes: after the four buttons, up to Open in Dia, at Dia's height.
static NSRect DPTitleFrame(NSView *title, DPLittleBar *bar) {
    NSRect bounds = title.superview.bounds;
    NSPoint diaOrigin = [DPGet(title, &DPDiaOriginKey) pointValue];
    NSSize diaSize = [DPGet(title, &DPDiaSizeKey) sizeValue];
    CGFloat left = DPInset + bar.leading.count * DPButton + (bar.leading.count - 1) * DPGap + DPInset;
    CGFloat right = NSWidth(bounds) - DPInset - bar.open.intrinsicContentSize.width - 6;
    return NSMakeRect(left, diaOrigin.y, MAX(0, right - left), diaSize.height);
}

static DPLittleBar *DPBarFor(NSView *title) {
    DPLittleBar *bar = DPGet(title, &DPBarKey);
    if (!bar) DPSet(title, &DPBarKey, bar = DPMakeBar(title));
    return bar;
}

// Dia keeps setting the address's frame; in a Little Dia window it gets this layout's instead.
static void DPTitle_setFrameOrigin(NSView *self, SEL _cmd, NSPoint origin) {
    if (!DPInPopupBar(self)) return DPCallOriginal(DPTitle_setFrameOrigin, self, origin);
    DPSet(self, &DPDiaOriginKey, [NSValue valueWithPoint:origin]);
    if (!DPShowsBar(self)) {
        DPRemoveBar(self);
        return DPCallOriginal(DPTitle_setFrameOrigin, self, origin);
    }
    DPCallOriginal(DPTitle_setFrameOrigin, self, DPTitleFrame(self, DPBarFor(self)).origin);
    DPPlaceBar(DPBarFor(self));
}

static void DPTitle_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    if (!DPInPopupBar(self)) return DPCallOriginal(DPTitle_setFrameSize, self, size);
    DPSet(self, &DPDiaSizeKey, [NSValue valueWithSize:size]);
    if (!DPGet(self, &DPDiaOriginKey)) DPSet(self, &DPDiaOriginKey, [NSValue valueWithPoint:self.frame.origin]);
    if (!DPShowsBar(self)) {
        DPRemoveBar(self);
        return DPCallOriginal(DPTitle_setFrameSize, self, size);
    }
    DPCallOriginal(DPTitle_setFrameSize, self, DPTitleFrame(self, DPBarFor(self)).size);
    DPPlaceBar(DPBarFor(self));
}

// Lays every popup's bar out again from the frame Dia last gave its address.
void DPRelayoutLittleDiaBars(void) {
    for (NSView *bar in DPFindViews(DPDiaPopupBar)) {
        NSView *title = DPFindView(bar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaPopupTitle); });
        if (!title) continue;
        NSValue *origin = DPGet(title, &DPDiaOriginKey), *size = DPGet(title, &DPDiaSizeKey);
        [title setFrameOrigin:origin ? origin.pointValue : title.frame.origin];
        [title setFrameSize:size ? size.sizeValue : title.frame.size];
    }
}

void DPInstallLittleDiaBar(void) {
    DPHook(DPDiaPopupTitle, @selector(setFrameOrigin:), (IMP)DPTitle_setFrameOrigin);
    DPHook(DPDiaPopupTitle, @selector(setFrameSize:), (IMP)DPTitle_setFrameSize);
}
