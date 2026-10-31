#import "SidebarToolbar.h"

static char DPMenuKey, DPRequestedFrameKey;
static const CGFloat DPExtensionsPadding = 6, DPExtensionsHeight = 40;

// Docked, Dia's pinned extensions live in a popover opened from the address field.
@interface DPExtensionsMenu : NSObject
@property (nonatomic, strong) NSButton *button;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, weak) NSView *extensions, *home;
@end

@implementation DPExtensionsMenu
- (instancetype)init {
    if (!(self = [super init])) return nil;
    NSImage *image = [NSImage imageWithSystemSymbolName:@"puzzlepiece.extension" accessibilityDescription:@"Extensions"];
    _button = [NSButton buttonWithImage:image target:self action:@selector(toggle:)];
    _button.bordered = NO;
    _button.contentTintColor = NSColor.secondaryLabelColor;
    _popover = [NSPopover new];
    _popover.behavior = NSPopoverBehaviorTransient;
    _popover.contentViewController = [NSViewController new];
    _popover.contentViewController.view = [NSView new];
    return self;
}

- (void)toggle:(NSButton *)sender {
    if (self.popover.shown) return [self.popover close];
    [self.popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:sender.isFlipped ? NSRectEdgeMaxY : NSRectEdgeMinY];
}

- (void)dock:(BOOL)docked {
    NSView *content = self.popover.contentViewController.view;
    NSValue *requested = DPGet(self.extensions, &DPRequestedFrameKey);
    if (docked && self.extensions.superview != content) [content addSubview:self.extensions];
    if (!docked && self.extensions.superview == content) {
        [self.popover close];
        [self.home addSubview:self.extensions];
        // Back where Dia last placed them, rather than at their spot in the popover.
        if (requested) self.extensions.frame = requested.rectValue;
        return;
    }
    // Re-applying Dia's last frame sizes the popover without recording the popover's own placement as Dia's.
    if (docked) self.extensions.frame = requested ? requested.rectValue : self.extensions.frame;
}
@end

// Dia keeps sizing the extensions for its bar; in the popover they take that width and the popover follows.
static void DPExtensions_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPSet(self, &DPRequestedFrameKey, @(frame));
    DPExtensionsMenu *menu = DPGet(self, &DPMenuKey);
    if (menu && self.superview == menu.popover.contentViewController.view) {
        frame = NSMakeRect(DPExtensionsPadding, 0, NSWidth(frame), DPExtensionsHeight);
        menu.popover.contentSize = NSMakeSize(NSWidth(frame) + 2 * DPExtensionsPadding, DPExtensionsHeight);
    }
    DPCallOriginal(DPExtensions_setFrame, self, frame);
}

void DPArrangeExtensions(NSView *bar, NSView *row, BOOL docked) {
    DPExtensionsMenu *menu = DPGet(bar, &DPMenuKey);
    if (!menu && docked) {
        NSView *extensions = DPSubview(row, DPDiaPinnedExtensions);
        if (!extensions) return;
        menu = [DPExtensionsMenu new];
        menu.extensions = extensions;
        menu.home = row;
        DPSet(bar, &DPMenuKey, menu);
        DPSet(extensions, &DPMenuKey, menu);
        [bar addSubview:menu.button positioned:NSWindowAbove relativeTo:row];
    }
    [menu dock:docked];
    menu.button.hidden = !docked || menu.extensions.hidden || NSWidth(menu.extensions.frame) < 1;
}

NSView *DPExtensionsButton(NSView *bar) {
    DPExtensionsMenu *menu = DPGet(bar, &DPMenuKey);
    return menu.button.hidden ? nil : menu.button;
}

// Extension popups open under the docked address instead of at the window's top right.
static void DPExtensionWindow_setFrame(NSWindow *self, SEL _cmd, NSRect frame, BOOL display) {
    for (NSWindow *window in NSApp.orderedWindows) {
        if (!DPIsKind(window, DPDiaWindow)) continue;
        NSView *field = nil;
        for (NSView *sidebar in DPSidebars) {
            NSView *bar = sidebar.window == window ? DPSubview(sidebar, DPDiaToolbar) : nil;
            if (bar) field = DPAddressField(bar);
        }
        if (field && !field.hidden) {
            NSRect anchor = [window convertRectToScreen:[field convertRect:field.bounds toView:nil]];
            frame.origin = NSMakePoint(NSMinX(anchor), MAX(NSMinY(anchor) - NSHeight(frame) - 4, NSMinY(window.screen.visibleFrame)));
        }
        break;
    }
    DPCallOriginal(DPExtensionWindow_setFrame, self, frame, display);
}

void DPInstallExtensions(void) {
    DPHook(DPDiaPinnedExtensions, @selector(setFrame:), (IMP)DPExtensions_setFrame);
    DPHook(DPDiaExtensionWindow, @selector(setFrame:display:), (IMP)DPExtensionWindow_setFrame);
}
