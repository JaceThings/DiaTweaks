#import "CompactSidebar.h"

// In the strip, New Tab shows only its plus, centered like the tabs' icons; Dia would cut its title to a letter.
static void DPNewTab_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNewTab_layout, self);
    BOOL strip = DPStripPresent(self.window) && NSWidth(self.bounds) <= DPStripWidth + DPRevealRoom(self.window) + 0.5;
    for (NSView *sub in self.subviews) {
        if (DPIsKind(sub, DPDiaTruncatingLabel)) {
            CGFloat alpha = strip ? 0 : 1;
            if (sub.alphaValue != alpha) sub.alphaValue = alpha;
        } else if (strip && [sub isKindOfClass:NSImageView.class]) {
            CGFloat x = round((NSWidth(self.bounds) - NSWidth(sub.frame)) / 2);
            if (NSMinX(sub.frame) != x) DPNow(^{ [sub setFrameOrigin:NSMakePoint(x, NSMinY(sub.frame))]; });
        }
    }
}

static void DPSidebar_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPSidebar_viewDidLayout, self);
    DPPlaceListIn(self.view.window);
}

// In the strip, tabs show only their icon, centered; Dia would start their titles beside it.
static void DPTabContent_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabContent_layout, self);
    BOOL strip = DPStripPresent(self.window) && NSWidth(self.bounds) <= DPStripWidth + DPRevealRoom(self.window);
    for (NSView *sub in self.subviews) {
        if (DPIsKind(sub, DPDiaTruncatingLabel)) {
            CGFloat alpha = strip ? 0 : 1;
            if (sub.alphaValue != alpha) sub.alphaValue = alpha;
        } else if (strip && !sub.hidden && NSWidth(sub.frame) == 16 && NSHeight(sub.frame) == 16) {
            CGFloat x = round((NSWidth(self.bounds) - 16) / 2);
            if (NSMinX(sub.frame) != x) DPNow(^{ [sub setFrameOrigin:NSMakePoint(x, NSMinY(sub.frame))]; });
        }
    }
}

static BOOL DPFooterInStrip(NSView *footer) {
    return footer && DPStripPresent(footer.window) && NSWidth(footer.bounds) <= DPStripWidth + DPRevealRoom(footer.window) + 0.5;
}

static void DPMove(NSView *view, CGFloat x) {
    x = round(x);
    if (NSMinX(view.frame) != x) DPNow(^{ [view setFrameOrigin:NSMakePoint(x, NSMinY(view.frame))]; });
}

// At the bottom of the strip, the recent tabs button is centered. With Hide Chats Button off, Chats shares the row with
// it: Chats in the left half as only its icon, recent tabs' arrow in the right; Dia would squeeze Chats under the arrow.
static void DPFooter_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPFooter_layout, self);
    if (!DPFooterInStrip(self)) return;
    NSView *chats = nil, *recent = nil;
    for (NSView *sub in self.subviews) {
        if (sub.hidden) continue;
        if (DPIsKind(sub, DPDiaSidebarOverflow)) recent = sub;
        else if (DPIsKind(sub, DPDiaLibraryCell)) chats = sub;
    }
    CGFloat width = NSWidth(self.bounds);
    if (chats) {
        NSRect frame = NSMakeRect(0, NSMinY(chats.frame), round(width / 2), NSHeight(chats.frame));
        if (!NSEqualRects(chats.frame, frame)) DPNow(^{ chats.frame = frame; });
    }
    if (!recent) return;
    // Its arrow is in its middle, so it centers in the strip, or in the right half beside Chats.
    DPMove(recent, (chats ? width * 3 / 4 : width / 2) - NSWidth(recent.frame) / 2);
}

// Chats in the strip: only its icon, centered, as the tabs show.
static void DPChats_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPChats_layout, self);
    BOOL strip = DPIsKind(self.superview, DPDiaSidebarFooter) && DPFooterInStrip(self.superview);
    for (NSView *sub in self.subviews) {
        if (DPIsKind(sub, DPDiaTruncatingLabel)) {
            CGFloat alpha = strip ? 0 : 1;
            if (sub.alphaValue != alpha) sub.alphaValue = alpha;
        } else if (strip && [sub isKindOfClass:NSImageView.class]) DPMove(sub, (NSWidth(self.bounds) - NSWidth(sub.frame)) / 2);
    }
}

void DPInstallCompactRows(void) {
    DPHook(DPDiaSidebarFooter, @selector(layout), (IMP)DPFooter_layout);
    DPHook(DPDiaLibraryCell, @selector(layout), (IMP)DPChats_layout);
    DPHook(DPDiaTabContent, @selector(layout), (IMP)DPTabContent_layout);
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPSidebar_viewDidLayout);
    DPHook(DPDiaNewTabButton, @selector(layout), (IMP)DPNewTab_layout);
}
