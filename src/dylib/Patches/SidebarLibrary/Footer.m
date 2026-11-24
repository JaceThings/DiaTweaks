#import "Library.h"
NSView *DPLibraryRecentView(NSWindow *window);
BOOL DPLibraryCanDismissRecent(NSView *view);
void DPLibraryBalanceFooter(NSView *footer);
@interface DPLibraryFooterButton : DPLibraryButton
@property NSView *preview;
@end
@implementation DPLibraryFooterButton
- (void)openLibrary:(id)sender { self.hovered=NO; self.needsDisplay=YES; [self.preview removeFromSuperview]; DPLibraryToggle(self.window); }
- (void)mouseEntered:(NSEvent *)event {
    [super mouseEntered:event]; if (!DPSidebarLibrary.on || !DPSidebarLibraryRecent.on || !self.window.isKeyWindow) return;
    extern DPLibraryController *DPLibraryForWindow(NSWindow *);
    if (DPLibraryForWindow(self.window).expanded) return;
    [self.preview removeFromSuperview]; self.preview = DPLibraryRecentView(self.window);
    if (!self.preview) return;
    NSView *content = self.window.contentView;
    NSRect anchor = [content convertRect:self.bounds fromView:self];
    NSRect frame = self.preview.frame; frame.origin.x = MAX(8,NSMinX(anchor));
    frame.origin.y = content.isFlipped ? NSMinY(anchor)-NSHeight(frame)-4 : NSMaxY(anchor)+4;
    if ([self.identifier hasSuffix:@"HorizontalButton"]) {
        frame.origin.x = NSMaxX(anchor)-NSWidth(frame);
        frame.origin.y = content.isFlipped ? NSMaxY(anchor)+4 : NSMinY(anchor)-NSHeight(frame)-4;
    }
    frame.origin.x = MAX(8,MIN(frame.origin.x,MAX(8,NSWidth(content.bounds)-NSWidth(frame)-8)));
    frame.origin.y = MAX(8,MIN(frame.origin.y,NSHeight(content.bounds)-NSHeight(frame)-8));
    self.preview.frame = frame; [content addSubview:self.preview positioned:NSWindowAbove relativeTo:nil];
}
- (void)mouseExited:(NSEvent *)event {
    [super mouseExited:event]; __weak DPLibraryFooterButton *weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,140*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{
        NSView *preview = weak.preview;
        NSPoint point = [preview convertPoint:weak.window.mouseLocationOutsideOfEventStream fromView:nil];
        if (DPLibraryCanDismissRecent(preview) && !NSPointInRect(point,preview.bounds)) [preview removeFromSuperview];
    });
}
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; if (!self.window) [self.preview removeFromSuperview]; }
@end
NSButton *DPLibraryMakeEntryButton(NSString *identifier) {
    DPLibraryFooterButton *button = [DPLibraryFooterButton buttonWithTitle:@"" target:nil action:@selector(openLibrary:)];
    button.target = button; button.bordered = NO; button.imagePosition = NSImageOnly;
    button.image = [DPLibraryEntryImage() imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightMedium]];
    button.contentTintColor = [identifier hasSuffix:@"HorizontalButton"] ? [NSColor.labelColor colorWithAlphaComponent:.68] : NSColor.secondaryLabelColor; button.identifier = identifier;
    button.accessibilityLabel = @"Open Sidebar Library"; button.toolTip = @"Sidebar Library (⇧⌘L)";
    return button;
}
static void DPPlaceLibraryFooter(NSView *footer) {
    DPLibraryBalanceFooter(footer);
    NSView *previous = DPFindView(footer,^BOOL(NSView *view) { return [view.identifier isEqual:@"DiaTweaks.SidebarLibrary.Button"]; });
    if (!DPSidebarLibrary.on) {
        [[(DPLibraryFooterButton *)previous preview] removeFromSuperview]; [previous removeFromSuperview]; return;
    }
    if (!previous) {
        NSButton *button = DPLibraryMakeEntryButton(@"DiaTweaks.SidebarLibrary.Button");
        [footer addSubview:button]; previous = button;
    }
    previous.frame = NSMakeRect(6,MAX(0,(NSHeight(footer.bounds)-30)/2),30,30);
}
static void DPLibraryFooterLayout(NSView *self, SEL _cmd) { DPCallOriginal(DPLibraryFooterLayout,self); DPPlaceLibraryFooter(self); }
static void DPLibraryFooterAttached(NSView *self, SEL _cmd) { DPCallOriginal(DPLibraryFooterAttached,self); DPPlaceLibraryFooter(self); }
void DPLibraryInstallFooter(void) {
    DPHook(DPDiaSidebarFooter,@selector(layout),(IMP)DPLibraryFooterLayout);
    DPHook(DPDiaSidebarFooter,@selector(viewDidMoveToWindow),(IMP)DPLibraryFooterAttached);
}
void DPLibraryRefreshFooters(void) { for (NSView *footer in DPFindViews(DPDiaSidebarFooter)) DPPlaceLibraryFooter(footer); }

void DPLibraryDismissRecent(NSWindow *window) {
    for (NSView *card in DPFindViews("DPLibraryRecent")) if (card.window == window) [card removeFromSuperview];
}
