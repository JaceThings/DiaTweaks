#import "StdPatch/StdPatch.h"

// Dia gives ⌘1–⌘9 to the sidebar's items and ⌃1–⌃9 to its profiles, in the menu bar. Picking ⌘1 for a profile in
// Dia's Shortcuts settings does nothing, because the sidebar item has it first. This swaps the two in the menus, and
// since a page takes ⌘ and a number before the menu bar sees it, runs the profile's item for those keys itself.

extern DPPatch DPProfileShortcuts;
static char DPSwappedKey;  // @[Dia's modifiers, ours] on an item this changed.

static BOOL DPIsDigitShortcut(NSMenuItem *item, NSEventModifierFlags mods) {
    NSString *key = item.keyEquivalent;
    return key.length == 1 && [key characterAtIndex:0] >= '1' && [key characterAtIndex:0] <= '9' && item.keyEquivalentModifierMask == mods;
}

static void DPSwapItem(NSMenuItem *item) {
    NSArray<NSNumber *> *swapped = DPGet(item, &DPSwappedKey);
    BOOL ours = swapped && item.keyEquivalentModifierMask == swapped[1].unsignedIntegerValue;
    if (!DPProfileShortcuts.on) {
        if (ours) item.keyEquivalentModifierMask = swapped[0].unsignedIntegerValue;
        if (swapped) DPSet(item, &DPSwappedKey, nil);
        return;
    }
    if (ours) return;
    NSEventModifierFlags to;
    if (DPIsDigitShortcut(item, NSEventModifierFlagCommand)) to = NSEventModifierFlagControl;
    else if (DPIsDigitShortcut(item, NSEventModifierFlagControl)) to = NSEventModifierFlagCommand;
    else return;
    DPSet(item, &DPSwappedKey, @[ @(item.keyEquivalentModifierMask), @(to) ]);
    item.keyEquivalentModifierMask = to;
}

static void DPSwapMenu(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        DPSwapItem(item);
        if (item.submenu) DPSwapMenu(item.submenu);
    }
}

static void DPApplyProfileShortcuts(DPPatch *patch) { DPSwapMenu(NSApp.mainMenu); }

static NSMenuItem *DPSwappedItemFor(NSMenu *menu, NSString *key) {
    for (NSMenuItem *item in menu.itemArray) {
        if (DPGet(item, &DPSwappedKey) && [item.keyEquivalent isEqualToString:key] && DPIsDigitShortcut(item, NSEventModifierFlagCommand)) return item;
        NSMenuItem *found = item.submenu ? DPSwappedItemFor(item.submenu, key) : nil;
        if (found) return found;
    }
    return nil;
}

static void DPApplication_sendEvent(NSApplication *self, SEL _cmd, NSEvent *event) {
    NSEventModifierFlags mods = event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift);
    NSMenuItem *item = DPProfileShortcuts.on && event.type == NSEventTypeKeyDown && mods == NSEventModifierFlagCommand
        ? DPSwappedItemFor(NSApp.mainMenu, event.charactersIgnoringModifiers) : nil;
    if (!item || !item.enabled) return DPCallOriginal(DPApplication_sendEvent, self, event);
    [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
}

// Dia rebuilds the profile items when profiles change, so the menus are swapped again after every change.
static void DPInstallProfileShortcuts(void) {
    DPHookClass(NSApplication.class, @selector(sendEvent:), (IMP)DPApplication_sendEvent);
    DPOnLaunch(^{
        DPApplyProfileShortcuts(&DPProfileShortcuts);
        __block BOOL pending = NO;
        void (^changed)(NSNotification *) = ^(NSNotification *note) {
            if (pending || !DPProfileShortcuts.on) return;
            pending = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                pending = NO;
                DPApplyProfileShortcuts(&DPProfileShortcuts);
            });
        };
        for (NSNotificationName name in @[ NSMenuDidAddItemNotification, NSMenuDidChangeItemNotification ])
            [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:changed];
    });
}

// The sidebar items, "Go to Sidebar Item 1" and on, show which way the swap went.
static NSMenuItem *DPSidebarItem(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqualToString:@"Go to Sidebar Item 1"]) return item;
        NSMenuItem *found = item.submenu ? DPSidebarItem(item.submenu) : nil;
        if (found) return found;
    }
    return nil;
}

static NSString *DPVerifyProfileShortcuts(DPPatch *patch) {
    NSMenuItem *item = DPSidebarItem(NSApp.mainMenu);
    if (!item || DPIsDigitShortcut(item, patch->on ? NSEventModifierFlagControl : NSEventModifierFlagCommand)) return nil;
    return patch->on ? @"the sidebar items keep ⌘ and a number" : @"the sidebar items didn't get ⌘ back";
}

DP_PATCH(DPProfileShortcuts) {
    .key = @"profileShortcuts",
    .order = 79,
    .title = @"Switch Profiles with ⌘1–9",
    .detail = @"Press ⌘ and a number to switch to that profile, like Arc's spaces. The sidebar's items move to ⌃ and a number.",
    .symbol = @"command",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .install = DPInstallProfileShortcuts,
    .apply = DPApplyProfileShortcuts,
    .verify = DPVerifyProfileShortcuts,
};
