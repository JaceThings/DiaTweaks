#import "CompactSidebar.h"

// In the strip, New Tab shows only its plus, centered like the tabs' icons; Dia would cut its title to a letter.
static void DPNewTab_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNewTab_layout, self);
    BOOL strip = DPStripPresent(self.window) && NSWidth(self.bounds) <= DPStripWidth + 0.5;
    for (NSView *sub in self.subviews) {
        if (DPIsKind(sub, DPDiaTruncatingLabel)) {
            CGFloat alpha = strip ? 0 : 1;
            if (sub.alphaValue != alpha) sub.alphaValue = alpha;
        } else if (strip && [sub isKindOfClass:NSImageView.class]) {
            [sub setFrameOrigin:NSMakePoint(round((NSWidth(self.bounds) - NSWidth(sub.frame)) / 2), NSMinY(sub.frame))];
        }
    }
}

// The tabs start level with the page card, under the toolbar, instead of under the window buttons. They move after the
// sidebar has laid out, as the compact header moves them, or the sidebar would lay itself out again and again.
static void DPSidebar_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPSidebar_viewDidLayout, self);
    NSView *root = self.view, *header = DPSubview(root, DPDiaSidebarHeader), *bar = nil;
    if (!DPStripPresent(root.window) || !header || !root.isFlipped) return;
    for (NSView *each in DPFindViews(DPDiaToolbar)) if (each.window == root.window) { bar = each; break; }
    NSView *list = nil;
    for (NSView *sub in root.subviews)
        if (DPIsKind(sub, DPDiaFlippedView) && fabs(NSMinY(sub.frame) - NSMaxY(header.frame)) < 12) { list = sub; break; }
    if (!bar || !list) return;
    // Where the toolbar ends once it shows: the card's top plus its height, even while Hide Toolbar lifts it out of sight.
    NSView *card = DPSubview(DPHostIn(root.window).superview, DPDiaContentContainer);
    if (!card) return;
    NSRect cardRect = [root convertRect:card.bounds fromView:card];
    CGFloat top = round(NSMinY(cardRect) + NSHeight(bar.bounds));
    if (fabs(NSMinY(list.frame) - top) < 0.25) return;
    list.frame = NSMakeRect(NSMinX(list.frame), top, NSWidth(list.frame), MAX(0, NSMaxY(list.frame) - top));
}

// In the strip, tabs show only their icon, centered; Dia would start their titles beside it.
static void DPTabContent_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabContent_layout, self);
    BOOL strip = DPStripPresent(self.window) && NSWidth(self.bounds) <= DPStripWidth;
    for (NSView *sub in self.subviews) {
        if (DPIsKind(sub, DPDiaTruncatingLabel)) {
            CGFloat alpha = strip ? 0 : 1;
            if (sub.alphaValue != alpha) sub.alphaValue = alpha;
        } else if (strip && !sub.hidden && NSWidth(sub.frame) == 16 && NSHeight(sub.frame) == 16) {
            CGFloat x = round((NSWidth(self.bounds) - 16) / 2);
            if (NSMinX(sub.frame) != x) [sub setFrameOrigin:NSMakePoint(x, NSMinY(sub.frame))];
        }
    }
}

// The recent tabs button at the bottom is centered in the strip too; Dia keeps room for the hidden library button.
static void DPFooter_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPFooter_layout, self);
    if (!DPStripPresent(self.window) || NSWidth(self.bounds) > DPStripWidth) return;
    for (NSView *sub in self.subviews) {
        if (!DPIsKind(sub, DPDiaSidebarOverflow) || sub.hidden) continue;
        CGFloat x = round((NSWidth(self.bounds) - NSWidth(sub.frame)) / 2);
        if (NSMinX(sub.frame) != x) [sub setFrameOrigin:NSMakePoint(x, NSMinY(sub.frame))];
    }
}

void DPInstallCompactRows(void) {
    DPHook(DPDiaSidebarFooter, @selector(layout), (IMP)DPFooter_layout);
    DPHook(DPDiaTabContent, @selector(layout), (IMP)DPTabContent_layout);
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPSidebar_viewDidLayout);
    DPHook(DPDiaNewTabButton, @selector(layout), (IMP)DPNewTab_layout);
}
