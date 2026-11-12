#import "CompactSidebar.h"

// The tabs start level with the page under the toolbar. With the toolbar hidden they rise to the page's top, into the
// header's empty space, and come down again as the window buttons show above them. Dia sets the list's frame as it lays
// the sidebar out; each frame it asks for is recorded and the list placed from that, so the two never take turns.
static char DPListFrameKey;
static const CGFloat DPListInset = 6;  // From the window's top, as the tabs are from the strip's sides.
static const CGFloat DPFirstRowInset = 6;  // Dia's room over the first row, which would leave it below the page's top.
static BOOL DPPlacingList;

static BOOL DPIsList(NSView *view) { return DPIsKind(view, DPDiaFlippedView) && DPIsKind(view.superview, DPDiaSidebarRoot); }

NSView *DPListIn(NSWindow *window) { return DPSubview(DPSidebarRootIn(window), DPDiaFlippedView); }

static NSRect DPDiaListFrame(NSView *list) {
    NSValue *dia = DPGet(list, &DPListFrameKey);
    return dia ? dia.rectValue : list.frame;
}

static NSRect DPListFrame(NSView *list, NSRect dia) {
    NSWindow *window = list.window;
    NSView *root = list.superview, *host = DPHostIn(window), *card = DPSubview(host.superview, DPDiaContentContainer);
    CGFloat footer = DPFooterRoom(window);  // What the footer grows by in the strip.
    dia.size.height = MAX(0, NSHeight(dia) - footer);
    if (!root.isFlipped) dia.origin.y += footer;
    if (!DPStripPresent(window) || DPStripExpanded(host) || !card) return dia;
    CGFloat shown = [root convertPoint:NSMakePoint(0, DPToolbarBottom(window)) fromView:nil].y;
    NSView *frameView = window.contentView.superview;
    CGFloat windowTop = NSMinY([root convertRect:frameView.bounds fromView:frameView]);
    CGFloat hidden = MAX(NSMinY([root convertRect:card.bounds fromView:card]), windowTop + DPListInset);
    CGFloat lights = MAX(DPToolbarAlpha(window), DPLightsReveal(window));
    CGFloat top = round(hidden + (shown - hidden) * lights) - DPFirstRowInset;  // The first row's top level with the page's.
    if (!isfinite(top) || top >= NSMaxY(dia)) return dia;
    return NSMakeRect(NSMinX(dia), top, NSWidth(dia), NSMaxY(dia) - top);
}

static void DPPlaceList(NSView *list) {
    NSRect frame = DPListFrame(list, DPDiaListFrame(list));
    if (NSEqualRects(list.frame, frame)) return;
    DPPlacingList = YES;
    DPNow(^{ list.frame = frame; });
    DPPlacingList = NO;
}

void DPPlaceListIn(NSWindow *window) {
    NSView *list = DPListIn(window);
    if (list) DPPlaceList(list);
}

static BOOL DPListAsked(NSView *view, NSRect frame) {
    if (DPPlacingList || !DPIsList(view)) return NO;
    DPSet(view, &DPListFrameKey, @(NSMakeRect(NSMinX(frame) + 0.0, NSMinY(frame) + 0.0, NSWidth(frame), NSHeight(frame))));
    DPPlacingList = YES;
    [view setFrame:DPListFrame(view, frame)];
    DPPlacingList = NO;
    return YES;
}

static void DPList_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    if (!DPListAsked(self, frame)) DPCallOriginal(DPList_setFrame, self, frame);
}

static void DPList_setFrameOrigin(NSView *self, SEL _cmd, NSPoint origin) {
    if (!DPListAsked(self, (NSRect){origin, DPDiaListFrame(self).size})) DPCallOriginal(DPList_setFrameOrigin, self, origin);
}

static void DPList_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    if (!DPListAsked(self, (NSRect){DPDiaListFrame(self).origin, size})) DPCallOriginal(DPList_setFrameSize, self, size);
}

void DPInstallCompactList(void) {
    DPHook(DPDiaFlippedView, @selector(setFrame:), (IMP)DPList_setFrame);
    DPHook(DPDiaFlippedView, @selector(setFrameOrigin:), (IMP)DPList_setFrameOrigin);
    DPHook(DPDiaFlippedView, @selector(setFrameSize:), (IMP)DPList_setFrameSize);
}
