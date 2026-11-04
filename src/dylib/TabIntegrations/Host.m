#import "Native.h"

static BOOL DPIntegrationHostHookInstalled;

BOOL DPIsIntegrationNativePreviewWindow(NSWindow *window) {
    Class cls = objc_getClass(DPDiaTabPreviewWindow);
    return window && cls && [window isKindOfClass:cls];
}

BOOL DPIntegrationHostAvailable(void) {
    return [objc_getClass(DPDiaTabPreviewWindow) isSubclassOfClass:NSWindow.class]
        && [objc_getClass(DPDiaTabPreviewRoot) isSubclassOfClass:NSViewController.class];
}

static void DPIntegration_orderWindow(NSWindow *self, SEL _cmd, NSWindowOrderingMode order, NSInteger relativeTo) {
    if (order != NSWindowOut && DPReplacesIntegrationHoverWindow(self)) return;
    DPCallOriginal(DPIntegration_orderWindow, self, order, relativeTo);
}

void DPInstallIntegrationHost(void) {
    if (DPIntegrationHostHookInstalled) return;
    Class cls = objc_getClass(DPDiaTabPreviewWindow);
    if (!cls) return;
    DPIntegrationHostHookInstalled = YES;
    DPHookClass(cls, @selector(orderWindow:relativeTo:), (IMP)DPIntegration_orderWindow);
}

@implementation DPTabIntegrationHost
- (instancetype)initWithPreview:(DPTabIntegrationPreview *)preview anchor:(NSView *)anchor {
    if (!(self = [super init]) || !preview || !anchor || !DPIntegrationHostAvailable()) return nil;

    self.preview = preview;
    self.anchor = anchor;
    self.root = [[objc_getClass(DPDiaTabPreviewRoot) alloc] initWithNibName:nil bundle:nil];
    self.window = [[objc_getClass(DPDiaTabPreviewWindow) alloc] init];
    if (!self.root || !self.window) return nil;
    self.window.releasedWhenClosed = NO;
    self.window.contentViewController = self.root;

    NSView *background = DPFindView(self.root.view, ^BOOL(NSView *view) {
        return [NSStringFromClass(view.class) isEqualToString:@DPDiaPopoverBackground];
    });
    id slot = [background safeSwiftValueForKey:@"contentView"];
    if (![slot isKindOfClass:NSView.class] || ![slot isDescendantOf:background]) return nil;
    self.background = background;
    self.slot = slot;
    self.window.appearance = anchor.effectiveAppearance;

    [self.window setContentSize:NSMakeSize(512, 512)];
    [self.root.view layoutSubtreeIfNeeded];
    NSRect bounds = self.root.view.bounds, frame = background.frame;
    self.shadowInsets = NSEdgeInsetsMake(NSMinY(frame), NSMinX(frame), NSMaxY(bounds) - NSMaxY(frame), NSMaxX(bounds) - NSMaxX(frame));

    [self.root addChildViewController:preview];
    NSView *content = preview.view;
    content.frame = self.slot.bounds;
    content.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.slot addSubview:content];
    __weak DPTabIntegrationHost *weak = self;
    preview.sizeChanged = ^(NSSize size) { [weak resize:size]; };
    [self resize:preview.preferredContentSize];
    return self;
}

- (void)resize:(NSSize)size { DPIntegrationHostResize(self, size); }
- (void)show { DPIntegrationHostShow(self); }
- (BOOL)containsPointer { return DPIntegrationHostContainsPointer(self); }
- (void)close { DPIntegrationHostClose(self); }
- (void)stopPreview {
    if (self.previewStopped) return;
    self.previewStopped = YES;
    [self.preview stop];
    self.preview.sizeChanged = nil;
}
- (void)dealloc {
    [self stopPreview];
    [self.window.parentWindow removeChildWindow:self.window];
    [self.window orderOut:nil];
}
@end
