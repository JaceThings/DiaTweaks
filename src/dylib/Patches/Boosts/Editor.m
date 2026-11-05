#import "Patches/Boosts/Editor.h"

static DPBoostEditor *DPEditor;

@implementation DPBoostEditor {
    BOOL _dirty;  // Typing saves a moment after it stops; closing saves what's left.
    id _clicks;
}

- (instancetype)initWithDomain:(NSString *)domain {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _domain = domain;
    NSDictionary *boost = DPBoostFor(domain) ?: DPCleanBoost(@{});
    _zaps = [boost[@"zaps"] mutableCopy];
    self.view = [self makeContent:boost];
    _popover = [NSPopover new];
    _popover.behavior = NSPopoverBehaviorApplicationDefined;  // See -popoverDidShow:.
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

// Each click on the page hides what's under it, until Escape or Done. The popover stays open meanwhile, listing them.
- (void)zap:(id)sender {
    if (self.zapping) return DPStopPicking(self.zapping);
    id contents = DPFrontContents();
    if (!contents || ![DPFrontDomain() isEqual:self.domain]) return NSBeep();  // The front tab is another site now.
    self.zapping = contents;
    [self showZapping];
    if (self.enabled.state != NSControlStateValueOn) {  // Zapping with the Boost off would hide nothing.
        self.enabled.state = NSControlStateValueOn;
        [self save];
    }
    [self.browserWindow makeKeyWindow];  // The page only follows the pointer while its window is key.
    __weak DPBoostEditor *weakSelf = self;
    DPPickElements(contents, ^(NSDictionary *zap) {
        DPBoostEditor *editor = weakSelf;
        NSDictionary *clean = [DPCleanBoost(@{ @"zaps" : @[ zap ] })[@"zaps"] firstObject];
        if (!editor || !clean) return;
        [editor.zaps addObject:clean];
        [editor save];
        [editor addZapRow:clean animated:YES];
    }, ^{
        weakSelf.zapping = nil;
        [weakSelf showZapping];
    });
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

// It closes itself like a transient popover, on a click outside it, Escape or Dia going to the background, but not while
// zapping, when the page's clicks are the picker's.
- (void)popoverDidShow:(NSNotification *)notification {
    __weak DPBoostEditor *weakSelf = self;
    _clicks = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskKeyDown
                                                    handler:^NSEvent *(NSEvent *event) {
        DPBoostEditor *editor = weakSelf;
        if (!editor || editor.zapping) return event;
        if (event.window == editor.view.window) {
            if (event.type != NSEventTypeKeyDown || event.keyCode != 53) return event;  // 53: Escape.
            [editor.popover close];
            return nil;
        }
        if (event.type == NSEventTypeKeyDown) return event;
        NSView *button = DPBoostButtonIn(event.window);
        BOOL onButton = button && NSPointInRect([button convertPoint:event.locationInWindow fromView:nil], button.bounds);
        [editor.popover close];
        return onButton ? nil : event;  // The paintbrush closes it rather than opening it again.
    }];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appDidResignActive:) name:NSApplicationDidResignActiveNotification object:nil];
}

- (void)appDidResignActive:(NSNotification *)notification {
    if (!self.zapping) [self.popover close];
}

- (void)popoverWillClose:(NSNotification *)notification {
    if (self.zapping) DPStopPicking(self.zapping);
    if (_dirty) [self save];
}

// The popover holds its controller, which holds the popover. Let go once the close is done.
- (void)popoverDidClose:(NSNotification *)notification {
    if (_clicks) [NSEvent removeMonitor:_clicks];
    _clicks = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];
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
    if (DPEditor.popover.shown && [DPEditor.domain isEqual:domain]) return;
    DPCloseBoostEditor();
    DPEditor = [[DPBoostEditor alloc] initWithDomain:domain];
    DPEditor.browserWindow = window;
    DPEditor.popover.contentSize = DPEditor.view.fittingSize;
    DPShowPopover(DPEditor.popover, window);
}

void DPCloseBoostEditor(void) { [DPEditor.popover close]; }
