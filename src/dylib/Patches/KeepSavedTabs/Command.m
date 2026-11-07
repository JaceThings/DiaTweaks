#import "KeepSavedTabs.h"

// ⌘W closes the whole tab only while one page fills the window and that page, the sidebar or the window has focus.
// Otherwise it's closing something smaller, like one side of a split or the chat.
static BOOL DPClosesWholeTab(NSWindow *window) {
    NSView *focus = [window.firstResponder isKindOfClass:NSView.class] ? (NSView *)window.firstResponder : nil;
    return DPSavedPanes(window) == 1 && (!focus || DPSavedEnclosing(focus, objc_getClass(DPDiaContentPane))
                                         || !DPSavedEnclosing(focus, objc_getClass(DPDiaContentContainer)));
}

// File > Close Tab.
static void DPWindow_closeFocusedContent(NSWindowController *self, SEL _cmd, id sender) {
    NSArray<NSView *> *tabs = DPKeepSavedTabs.on ? DPSavedTabsIn(self.window.contentView) : nil;
    NSIndexSet *selected = [tabs indexesOfObjectsPassingTest:^BOOL(NSView *tab, NSUInteger i, BOOL *stop) { return DPSavedIsSelected(tab); }];
    if (selected.count != 1 || !DPClosesWholeTab(self.window) || !DPSavedClose(tabs[selected.firstIndex]))
        DPCallOriginal(DPWindow_closeFocusedContent, self, sender);
}

void DPInstallSavedCommand(void) {
    DPHook(DPDiaWindowController, NSSelectorFromString(@"closeFocusedContent:"), (IMP)DPWindow_closeFocusedContent);
}
