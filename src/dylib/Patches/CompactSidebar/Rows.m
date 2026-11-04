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

// The recent tabs button at the bottom is centered in the strip too; Dia keeps room for the hidden library button.
static void DPFooter_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPFooter_layout, self);
    if (!DPStripPresent(self.window) || NSWidth(self.bounds) > DPStripWidth + DPRevealRoom(self.window)) return;
    for (NSView *sub in self.subviews) {
        if (!DPIsKind(sub, DPDiaSidebarOverflow) || sub.hidden) continue;
        CGFloat x = round((NSWidth(self.bounds) - NSWidth(sub.frame)) / 2);
        if (NSMinX(sub.frame) != x) DPNow(^{ [sub setFrameOrigin:NSMakePoint(x, NSMinY(sub.frame))]; });
    }
}

void DPInstallCompactRows(void) {
    DPHook(DPDiaSidebarFooter, @selector(layout), (IMP)DPFooter_layout);
    DPHook(DPDiaTabContent, @selector(layout), (IMP)DPTabContent_layout);
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPSidebar_viewDidLayout);
    DPHook(DPDiaNewTabButton, @selector(layout), (IMP)DPNewTab_layout);
}
