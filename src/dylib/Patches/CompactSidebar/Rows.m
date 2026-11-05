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

static void DPPlaceFooter(NSView *root);

static void DPSidebar_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPSidebar_viewDidLayout, self);
    DPPlaceFooter(DPSidebarRootIn(self.view.window));
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

static char DPFooterFrameKey;

static BOOL DPFooterInStrip(NSView *footer) {
    return footer && DPStripPresent(footer.window) && NSWidth(footer.bounds) <= DPStripWidth + DPRevealRoom(footer.window) + 0.5;
}

static void DPMove(NSView *view, CGFloat x) {
    x = round(x);
    if (NSMinX(view.frame) != x) DPNow(^{ [view setFrameOrigin:NSMakePoint(x, NSMinY(view.frame))]; });
}

static void DPPlace(NSView *view, NSRect frame) {
    if (!NSEqualRects(view.frame, frame)) DPNow(^{ view.frame = frame; });
}

static NSView *DPFooterItem(NSView *footer, const char *kind) {
    for (NSView *sub in footer.subviews) if (!sub.hidden && DPIsKind(sub, kind)) return sub;
    return nil;
}

// The footer's height as Dia lays it out: one row.
static CGFloat DPFooterRow(NSView *footer) { return NSHeight([DPDiaValue(footer, &DPFooterFrameKey, @(footer.frame)) rectValue]); }

// With Hide Chats Button off, Chats goes on a row of its own over recent tabs: side by side they don't fit the strip.
CGFloat DPChatsRoom(NSWindow *window) {
    NSView *footer = DPSubview(DPSidebarRootIn(window), DPDiaSidebarFooter);
    BOOL both = DPFooterItem(footer, DPDiaSidebarOverflow) && DPFooterItem(footer, DPDiaLibraryCell);
    return DPFooterInStrip(footer) && both ? DPFooterRow(footer) : 0;
}

// The footer grows up by that row, and the tabs above give it up (List.m).
static void DPPlaceFooter(NSView *root) {
    NSView *footer = DPSubview(root, DPDiaSidebarFooter);
    if (!footer) return;
    NSRect dia = [DPDiaValue(footer, &DPFooterFrameKey, @(footer.frame)) rectValue], frame = dia;
    CGFloat room = DPChatsRoom(root.window);
    frame.size.height += room;
    if (root.isFlipped) frame.origin.y -= room;
    DPOverride(footer, &DPFooterFrameKey, @(dia), @(frame));
    DPPlace(footer, frame);
}

// At the bottom of the strip, the recent tabs button is centered, with Chats over it while it shows.
static void DPFooter_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPFooter_layout, self);
    if (!DPFooterInStrip(self)) return;
    NSView *chats = DPFooterItem(self, DPDiaLibraryCell), *recent = DPFooterItem(self, DPDiaSidebarOverflow);
    CGFloat width = NSWidth(self.bounds);
    if (!recent) return;
    if (!chats) return DPMove(recent, (width - NSWidth(recent.frame)) / 2);
    // Chats' highlight is inset from its sides, so it's wider than recent tabs by that, and its highlight matches.
    CGFloat row = DPFooterRow(self), chatsWidth = MIN(width, NSWidth(recent.frame) + 12);
    CGFloat recentY = self.isFlipped ? NSHeight(self.bounds) - row : 0, chatsY = self.isFlipped ? recentY - row : row;
    DPPlace(recent, NSMakeRect(round((width - NSWidth(recent.frame)) / 2), recentY, NSWidth(recent.frame), MIN(row, NSHeight(recent.frame))));
    DPPlace(chats, NSMakeRect(round((width - chatsWidth) / 2), chatsY, chatsWidth, row));
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
