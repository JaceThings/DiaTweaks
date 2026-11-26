#import "CustomProfileColor.h"

// Dia's Edit Profile submenu: color swatches, Rename…, Profile Settings. Ours go above Rename….
static NSString *const DPRenameTitle = @"Rename", *const DPSettingsTitle = @"Profile Settings";
static char DPOursKey;
static NSString *DPClickedSpaceID;
static BOOL DPAdding;

@interface DPProfileColorTarget : NSObject
@property(copy) NSString *spaceID;
@end

@implementation DPProfileColorTarget
- (void)changeColor:(NSColorPanel *)panel { DPSetCustomColor(self.spaceID, panel.color); }

- (void)choose:(NSMenuItem *)item {
    self.spaceID = item.representedObject;
    NSColorPanel *panel = NSColorPanel.sharedColorPanel;
    panel.target = nil;
    panel.action = NULL;
    panel.showsAlpha = YES;
    panel.mode = NSColorPanelModeWheel;
    panel.continuous = YES;
    panel.color = DPCustomColor(self.spaceID) ?: DPDiaProfileColor(NSApp.keyWindow) ?: NSColor.systemBlueColor;
    panel.target = self;
    panel.action = @selector(changeColor:);
    [panel makeKeyAndOrderFront:nil];
}

- (void)reset:(NSMenuItem *)item {
    if ([self.spaceID isEqual:item.representedObject]) {
        NSColorPanel.sharedColorPanel.target = nil;
        NSColorPanel.sharedColorPanel.action = NULL;
        self.spaceID = nil;
    }
    DPSetCustomColor(item.representedObject, nil);
}
@end

static DPProfileColorTarget *DPTarget;

static NSInteger DPIndexOf(NSMenu *menu, NSString *prefix) {
    for (NSInteger i = 0; i < menu.numberOfItems; i++)
        if ([[menu itemAtIndex:i].title hasPrefix:prefix]) return i;
    return -1;
}

static void DPUpdateMenu(NSMenu *menu) {
    NSArray<NSMenuItem *> *ours = DPGet(menu, &DPOursKey);
    BOOL dias = DPIndexOf(menu, DPSettingsTitle) >= 0 && DPIndexOf(menu, DPRenameTitle) >= 0;
    if (!DPCustomProfileColor.on || !dias) {
        for (NSMenuItem *item in ours) if (item.menu == menu) [menu removeItem:item];
        DPSet(menu, &DPOursKey, nil);
        return;
    }
    if (!ours) {
        NSMenuItem *choose = [[NSMenuItem alloc] initWithTitle:@"Custom Color…" action:@selector(choose:) keyEquivalent:@""];
        NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:@"Use Dia’s Color" action:@selector(reset:) keyEquivalent:@""];
        choose.image = [NSImage imageWithSystemSymbolName:@"paintpalette" accessibilityDescription:nil];
        ours = @[ choose, reset, NSMenuItem.separatorItem ];
        DPAdding = YES;
        NSInteger at = DPIndexOf(menu, DPRenameTitle);
        for (NSMenuItem *item in ours) [menu insertItem:item atIndex:at++];
        DPAdding = NO;
        DPSet(menu, &DPOursKey, ours);
    }
    NSString *spaceID = DPClickedSpaceID ?: DPCurrentSpaceID(NSApp.keyWindow ?: NSApp.mainWindow);
    for (NSMenuItem *item in ours) {
        item.target = DPTarget;
        item.representedObject = spaceID;
    }
    ours[0].enabled = spaceID != nil;
    ours[1].hidden = !DPCustomColor(spaceID);
}

static void DPUpdateMenuTree(NSMenu *menu) {
    DPUpdateMenu(menu);
    for (NSMenuItem *item in menu.itemArray) if (item.submenu) DPUpdateMenuTree(item.submenu);
}

void DPInstallProfileColorMenu(void) {
    DPTarget = [DPProfileColorTarget new];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    // A submenu Dia fills as it opens gets its items after the root menu starts tracking.
    [center addObserverForName:NSMenuDidAddItemNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSMenu *menu = note.object;
        NSInteger index = [note.userInfo[@"NSMenuItemIndex"] integerValue];
        if (DPAdding || index >= menu.numberOfItems || ![[menu itemAtIndex:index].title hasPrefix:DPSettingsTitle]) return;
        DPUpdateMenu(menu);
    }];
    [center addObserverForName:NSMenuDidBeginTrackingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        DPUpdateMenuTree(note.object);
    }];
    DPOnLaunch(^{
        // Right-clicking a profile in the switcher edits that profile, not the current one.
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown handler:^NSEvent *(NSEvent *event) {
            NSView *frame = event.window.contentView.superview;
            NSView *hit = [frame hitTest:event.locationInWindow];  // The theme frame has no superview: its coordinates are the window's.
            DPClickedSpaceID = nil;
            for (NSView *view = hit; view; view = view.superview)
                if (DPIsKind(view, DPDiaSpaceSwitcherItem)) { DPClickedSpaceID = DPSpaceIDOfItem(view); break; }
            return event;
        }];
    });
}
