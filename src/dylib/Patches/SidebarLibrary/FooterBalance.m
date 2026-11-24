#import "Library.h"
static char DPLibrarySwitcherFrameKey;
void DPLibraryBalanceFooter(NSView *footer) {
    NSView *switcher = DPSubview(footer,DPDiaSpaceSwitcher); if (!switcher) return;
    NSArray *saved = DPGet(switcher,&DPLibrarySwitcherFrameKey);
    NSRect native = saved.count == 2 && NSEqualRects(switcher.frame,[saved[1] rectValue]) ? [saved[0] rectValue] : switcher.frame;
    if (!DPSidebarLibrary.on) {
        if (saved) { DPSet(switcher,&DPLibrarySwitcherFrameKey,nil); switcher.frame = native; }
        return;
    }
    if (NSWidth(footer.bounds) < 110) return;
    // Equal gutters keep the spaces centered whether the right control is
    // present or hidden. Native SpaceSwitcher still lays out its own items.
    NSRect frame = native; frame.origin.x = 42; frame.size.width = NSWidth(footer.bounds)-84;
    DPSet(switcher,&DPLibrarySwitcherFrameKey,@[[NSValue valueWithRect:native],[NSValue valueWithRect:frame]]);
    if (!NSEqualRects(switcher.frame,frame)) {
        switcher.frame = frame; switcher.needsLayout = YES; [switcher layoutSubtreeIfNeeded];
    }
}
