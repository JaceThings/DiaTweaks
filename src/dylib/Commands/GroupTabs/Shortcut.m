#import "GroupTabs.h"

// Stays installed while Group Tabs is off, and passes the key on, so turning the patch on needs no relaunch.
extern DPPatch DPGroupTabs;
static id DPKeyMonitor;
static NSString *const DPGroupTabsShortcutKey = @"groupTabsByDomainShortcut";

// ⌃⇧G. ⌘G and ⇧⌘G are Find Next and Find Previous, and ⌃⌘N is Dia's New Group with Selected Tabs.
static NSDictionary *DPDefaultGroupTabsShortcut(void) {
    return @{ @"keyCode" : @5, @"modifiers" : @(NSEventModifierFlagControl | NSEventModifierFlagShift), @"key" : @"G" };
}

void DPInstallGroupTabsShortcut(void) {
    DPKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (!DPGroupTabs.on || !DPShortcutMatches(event, DPGroupTabsShortcutKey, DPDefaultGroupTabsShortcut()) || !DPCommandBrowser()) return event;
        if (!event.isARepeat) DPGroupTabsOnce();
        return nil;
    }];
}

NSArray<NSView *> *DPGroupTabsShortcutRows(void) {
    NSStackView *row = [NSStackView stackViewWithViews:@[ [NSTextField labelWithString:@"Shortcut"], DPShortcutField(DPGroupTabsShortcutKey, DPDefaultGroupTabsShortcut()) ]];
    row.distribution = NSStackViewDistributionEqualCentering;
    return @[ row ];
}

NSString *DPVerifyGroupTabsShortcut(DPPatch *patch) { return DPKeyMonitor ? nil : @"nothing listens for the shortcut"; }
