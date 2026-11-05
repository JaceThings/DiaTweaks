#import "GroupTabs.h"

extern DPPatch DPGroupTabs;

// ⌃⇧G. ⌘G and ⇧⌘G are Find Next and Find Previous, and ⌃⌘N is Dia's New Group with Selected Tabs.
NSDictionary *DPDefaultGroupTabsShortcut(void) {
    return @{ @"keyCode" : @5, @"modifiers" : @(NSEventModifierFlagControl | NSEventModifierFlagShift), @"key" : @"G" };
}

// Stays installed while Group Tabs is off, and passes the key on, so turning the patch on needs no relaunch.
void DPInstallGroupTabsShortcut(void) {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (!DPGroupTabs.on || !DPShortcutMatches(event, &DPGroupTabs) || !DPCommandBrowser()) return event;
        if (!event.isARepeat) DPGroupTabsOnce();
        return nil;
    }];
}
