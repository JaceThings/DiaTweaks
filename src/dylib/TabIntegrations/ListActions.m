#import "ListRows.h"
#import "ListPreview.h"

@interface DPIntegrationListMoreButton : NSButton
@end
@implementation DPIntegrationListMoreButton
- (void)showActions:(id)sender {
    [self.menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight(self.bounds)) inView:self];
}
@end

@interface DPIntegrationListActionButton : NSButton
@property(nonatomic, strong) DPTabIntegrationAction *integrationAction;
@property(nonatomic, strong) DPTabIntegrationItem *item;
@end
@implementation DPIntegrationListActionButton
@end

@interface DPIntegrationListMenuEntry : NSObject
@property(nonatomic, strong) DPTabIntegrationAction *action;
@property(nonatomic, strong) DPTabIntegrationItem *item;
@end
@implementation DPIntegrationListMenuEntry
@end

void DPIntegrationListPerformAction(NSButton *sender, DPTabIntegrationContext *context) {
    DPIntegrationListActionButton *button = (DPIntegrationListActionButton *)sender;
    if (button.enabled && button.integrationAction.enabled && button.integrationAction.handler) button.integrationAction.handler(context, button.item);
}

void DPIntegrationListPerformMenuAction(NSMenuItem *menuItem, DPTabIntegrationContext *context) {
    DPIntegrationListMenuEntry *entry = menuItem.representedObject;
    if (entry.action.handler && menuItem.enabled) entry.action.handler(context, entry.item);
}

NSButton *DPIntegrationListMakeMoreActionsButton(NSArray<DPTabIntegrationAction *> *actions, DPTabIntegrationItem *item,
                                    NSRect frame, DPTabIntegrationListPreview *preview, BOOL cached) {
    NSButton *button = [[DPIntegrationListMoreButton alloc] initWithFrame:frame];
    button.bordered = NO;
    button.image = [NSImage imageWithSystemSymbolName:@"ellipsis" accessibilityDescription:@"More actions"];
    button.contentTintColor = NSColor.secondaryLabelColor;
    button.accessibilityLabel = @"More actions";
    button.toolTip = @"More actions";
    button.enabled = YES;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Actions"];
    menu.autoenablesItems = NO;
    for (DPTabIntegrationAction *action in actions) {
        NSMenuItem *entryItem = [[NSMenuItem alloc] initWithTitle:action.title ?: @"Action"
            action:@selector(performListMenuAction:) keyEquivalent:@""];
        entryItem.target = preview;
        entryItem.enabled = action.enabled && (!cached || action.enabledWhenCached);
        entryItem.accessibilityLabel = action.accessibilityTitle ?: action.title;
        DPIntegrationListMenuEntry *entry = [DPIntegrationListMenuEntry new];
        entry.action = action; entry.item = item;
        entryItem.representedObject = entry;
        [menu addItem:entryItem];
    }
    button.menu = menu;
    button.target = button; button.action = @selector(showActions:);
    return button;
}

NSButton *DPIntegrationListMakeActionButton(DPTabIntegrationAction *action, DPTabIntegrationItem *item,
                               NSRect frame, DPTabIntegrationListPreview *preview, BOOL cached) {
    DPIntegrationListActionButton *button = [[DPIntegrationListActionButton alloc] initWithFrame:frame];
    button.bordered = NO;
    button.target = preview;
    button.action = @selector(performListAction:);
    button.integrationAction = action;
    button.item = item;
    if (action.symbolName.length) {
        button.image = [NSImage imageWithSystemSymbolName:action.symbolName accessibilityDescription:action.accessibilityTitle ?: action.title];
        button.contentTintColor = [action.symbolName isEqualToString:@"pin.fill"] ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
    } else {
        button.title = action.title ?: @"Action";
        button.font = [NSFont systemFontOfSize:11];
    }
    button.toolTip = action.title;
    button.accessibilityLabel = action.accessibilityTitle ?: action.title;
    button.enabled = action.enabled && (!cached || action.enabledWhenCached);
    return button;
}
