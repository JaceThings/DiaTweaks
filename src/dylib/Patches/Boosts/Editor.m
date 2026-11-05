#import "Patches/Boosts/Editor.h"

static DPBoostEditor *DPEditor;

@implementation DPBoostEditor {
    BOOL _dirty;  // Typing saves a moment after it stops; closing saves what's left.
}

- (instancetype)initWithDomain:(NSString *)domain {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _domain = domain;
    NSDictionary *boost = DPBoostFor(domain) ?: DPCleanBoost(@{});
    _zaps = [boost[@"zaps"] mutableCopy];
    self.view = [self makeContent:boost];
    _popover = [NSPopover new];
    _popover.behavior = NSPopoverBehaviorTransient;
    _popover.contentViewController = self;
    _popover.delegate = self;
    return self;
}

- (void)save {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    _dirty = NO;
    DPSaveBoost(self.domain, DPCleanBoost(@{
        @"enabled" : @(self.enabled.state == NSControlStateValueOn), @"zaps" : self.zaps.copy,
        @"font" : self.font.selectedItem.representedObject ?: @"", @"css" : self.css.string.copy, @"js" : self.js.string.copy,
    }));
}

- (void)changed:(id)sender { [self save]; }

- (void)textDidChange:(NSNotification *)notification {
    _dirty = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    [self performSelector:@selector(save) withObject:nil afterDelay:0.4];
}

- (void)fit { self.popover.contentSize = self.view.fittingSize; }

// The page needs the clicks, so the popover steps aside and comes back once something is picked or Escape is pressed.
- (void)zap:(id)sender {
    id contents = DPFrontContents();
    if (!contents || ![DPFrontDomain() isEqual:self.domain]) return NSBeep();  // The front tab is another site now.
    NSString *domain = self.domain;
    NSWindow *window = self.browserWindow;
    [self.popover close];
    [window makeKeyAndOrderFront:nil];  // The page only gets the click once its window is key.
    DPPickElement(contents, ^(NSDictionary *zap) {
        if (zap) {
            NSMutableDictionary *boost = [DPBoostFor(domain) ?: DPCleanBoost(@{}) mutableCopy];
            boost[@"zaps"] = [boost[@"zaps"] arrayByAddingObject:zap];
            DPSaveBoost(domain, DPCleanBoost(boost));
        }
        if ([DPFrontDomain() isEqual:domain]) DPShowBoostEditor(domain);
    });
}

- (void)unzap:(NSButton *)sender {
    if ((NSUInteger)sender.tag >= self.zaps.count) return;
    [self.zaps removeObjectAtIndex:sender.tag];
    [self save];
    [self reloadZapList];
    [self fit];
}

// Sheets go on the browser window: the popover closes first, saving what's left.
- (void)importBoost:(id)sender {
    NSWindow *window = self.browserWindow;
    [self.popover close];
    DPImportBoost(window);
}

- (void)exportBoost:(id)sender {
    NSWindow *window = self.browserWindow;
    [self.popover close];
    DPExportBoost(self.domain, window);
}

- (void)deleteBoost:(id)sender {
    NSString *domain = self.domain;
    NSWindow *window = self.browserWindow;
    [self.popover close];
    NSAlert *alert = [NSAlert new];
    alert.messageText = [NSString stringWithFormat:@"Delete the Boost for %@?", domain];
    alert.informativeText = @"The site goes back to how it looks without it.";
    [alert addButtonWithTitle:@"Delete"].hasDestructiveAction = YES;
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPSaveBoost(domain, nil);
    }];
}

- (void)popoverWillClose:(NSNotification *)notification {
    if (_dirty) [self save];
}

// The popover holds its controller, which holds the popover. Let go once the close is done.
- (void)popoverDidClose:(NSNotification *)notification {
    if (DPEditor == self) DPEditor = nil;
    dispatch_async(dispatch_get_main_queue(), ^{ self.popover = nil; });
}

@end

static NSWindow *DPBrowserWindow(void) {
    if (DPIsKind(NSApp.mainWindow, DPDiaWindow)) return NSApp.mainWindow;
    for (NSWindow *window in NSApp.orderedWindows)
        if (DPIsKind(window, DPDiaWindow) && window.visible) return window;
    return nil;
}

// Under the Boost button, else under the address field, else under the top of the window while the toolbar is hidden.
// A popover closes when the view it points at hides, and Dia hides the button and the field as the pointer leaves
// them, so it points at the window's content view where the button is.
static void DPShowPopover(NSPopover *popover, NSWindow *window) {
    NSView *content = window.contentView;
    NSView *target = DPBoostButtonIn(window) ?: DPFindView(content, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaAddressField) && !view.isHiddenOrHasHiddenAncestor;
    });
    NSRect rect = target ? [content convertRect:target.bounds fromView:target]
                         : NSMakeRect(NSMidX(content.bounds), content.isFlipped ? 0 : NSMaxY(content.bounds) - 1, 1, 1);
    [popover showRelativeToRect:rect ofView:content preferredEdge:content.isFlipped ? NSRectEdgeMaxY : NSRectEdgeMinY];
}

void DPShowBoostEditor(NSString *domain) {
    NSWindow *window = DPBrowserWindow();
    if (!window) return NSBeep();
    DPStopPicking(DPFrontContents());  // A zap still waiting for a click ends: the popover is back.
    if (DPEditor.popover.shown && [DPEditor.domain isEqual:domain]) return;
    DPCloseBoostEditor();
    DPEditor = [[DPBoostEditor alloc] initWithDomain:domain];
    DPEditor.browserWindow = window;
    DPShowPopover(DPEditor.popover, window);
    [DPEditor fit];
}

void DPCloseBoostEditor(void) { [DPEditor.popover close]; }
