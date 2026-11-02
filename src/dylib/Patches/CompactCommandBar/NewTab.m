#import "CompactCommandBar.h"

static char DPTrimKey;

// The panel is also Dia's chat, so only the new tab page's one changes. The page pins its top, so it shrinks upward.
static void DPAssistantPanel_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    NSSize compact = DPIsKind(self.superview.superview, DPDiaNewTabPage) ? DPCompactSize(self, size) : size;
    DPSet(self, &DPTrimKey, compact.height < size.height ? @(size.height - compact.height) : nil);
    DPCallOriginal(DPAssistantPanel_setFrameSize, self, compact);
}

// The command bar fills the panel and would squeeze the suggestions to keep room for the row, so it keeps its height
// and the panel's rounded card clips the empty row instead.
static void DPCommandBar_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    NSView *panel = self.superview.superview;
    if (DPIsKind(panel, DPDiaAssistantPanel)) size.height += [DPGet(panel, &DPTrimKey) doubleValue];
    DPCallOriginal(DPCommandBar_setFrameSize, self, size);
}

// A switch flip doesn't make Dia size an open new tab page's panel again, so it's given its full size here to trim or not.
void DPResizeNewTabPanels(void) {
    for (NSView *panel in DPFindViews(DPDiaAssistantPanel)) {
        if (!DPIsKind(panel.superview.superview, DPDiaNewTabPage)) continue;
        NSSize size = panel.frame.size;
        size.height += [DPGet(panel, &DPTrimKey) doubleValue];
        [panel setFrameSize:size];
        panel.superview.superview.needsLayout = YES;  // Dia places the chat usage banner under the panel as it lays the page out.
    }
}

void DPInstallNewTabLayout(void) {
    DPHook(DPDiaAssistantPanel, @selector(setFrameSize:), (IMP)DPAssistantPanel_setFrameSize);
    DPHook(DPDiaCommandBar, @selector(setFrameSize:), (IMP)DPCommandBar_setFrameSize);
}
