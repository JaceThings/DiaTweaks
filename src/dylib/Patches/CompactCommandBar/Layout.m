#import "CompactCommandBar.h"

static const CGFloat DPCommandBarSpacing = 14;
static char DPCompactedKey, DPPopoverTrimKey;

// The popover and the new tab page's panel size themselves to the command bar, so they drop the bottom row's height,
// keeping as much space under the input (or the suggestions) as the input has between it and the suggestions.
NSSize DPCompactSize(NSView *container, NSSize size) {
    NSView *commandBar = DPCommandBarPart(container, DPDiaCommandBar), *toolbar = DPCompactToolbar(commandBar);
    NSView *input = DPCommandBarPart(commandBar, DPDiaCommandBarInput), *suggestions = DPCommandBarPart(commandBar, DPDiaCommandBarSuggestions);
    if (toolbar && input && suggestions) {
        CGFloat gap = NSMinY(suggestions.frame) - NSMaxY(input.frame), below = NSMinY(input.frame) - gap;
        size.height -= MAX(0, NSHeight(toolbar.frame) - below);
    }
    return size;
}

static void DPPopover_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    NSSize compact = DPCompactSize(self, size);
    DPSet(self, &DPPopoverTrimKey, compact.height < size.height ? @(size.height - compact.height) : nil);
    DPCallOriginal(DPPopover_setFrameSize, self, compact);
}

// A switch flip doesn't make Dia size an open popover again, so it's given its full size here to trim or not, keeping its top.
void DPResizePopovers(void) {
    for (NSView *popover in DPFindViews(DPDiaPopover)) {
        if (!DPCommandBarPart(popover, DPDiaCommandBar)) continue;
        NSRect before = popover.frame;
        [popover setFrameSize:NSMakeSize(NSWidth(before), NSHeight(before) + [DPGet(popover, &DPPopoverTrimKey) doubleValue])];
        if (!popover.superview.isFlipped) [popover setFrameOrigin:NSMakePoint(NSMinX(before), NSMaxY(before) - NSHeight(popover.frame))];
    }
}

static void DPPopover_setFrameOrigin(NSView *self, SEL _cmd, NSPoint origin) {
    DPCallOriginal(DPPopover_setFrameOrigin, self, origin);
    NSView *commandBar = DPCommandBarPart(self, DPDiaCommandBar);
    if (DPCompactToolbar(commandBar)) commandBar.needsLayout = YES;
}

// Go moves up beside the input, and the row is still full width so it keeps its place at the trailing edge.
// Dia lets the popover run past the top of the window, so Go is centered in the part of the row that shows.
static void DPCommandBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPCommandBar_layout, self);
    NSView *toolbar = DPCommandBarPart(self, DPDiaCommandBarToolbar);
    NSStackView *stack = toolbar.subviews.firstObject;
    if (![stack isKindOfClass:NSStackView.class]) return;
    BOOL compact = DPCompactToolbar(self) != nil;
    if (!compact && !DPGet(stack, &DPCompactedKey)) return;
    DPSet(stack, &DPCompactedKey, compact ? @YES : nil);
    // Faded rather than hidden: the add tabs button stretches to push Go to the trailing edge. Before Dia labels them,
    // the buttons can't be told apart, so all but Go fade.
    for (NSView *view in stack.views)
        if (view != DPGoButton(toolbar)) view.alphaValue = !compact;
    NSView *input = DPCommandBarPart(self, DPDiaCommandBarInput), *suggestions = DPCommandBarPart(self, DPDiaCommandBarSuggestions);
    if (!compact || !input || !suggestions || !self.window) return;
    CGFloat gap = NSMinY(suggestions.frame) - NSMaxY(input.frame), rowBottom = NSMinY(suggestions.frame) + NSMinY(input.frame) - gap;
    CGFloat cut = MAX(0, NSMaxY([self convertRect:self.bounds toView:nil]) - NSHeight(self.window.frame));
    NSRect frame = toolbar.frame;
    frame.origin.y = (MIN(cut, NSMinY(input.frame)) + rowBottom - NSHeight(frame)) / 2;
    toolbar.frame = frame;
}

// The text stops short of Go instead of running under it.
static void DPCommandBarInput_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPCommandBarInput_layout, self);
    NSView *go = DPGoButton(DPCompactToolbar(self.superview)), *text = DPCommandBarPart(self, DPDiaCommandBarText);
    if (!go || !text) return;
    NSRect frame = text.frame;
    frame.size.width = MAX(0, NSWidth(self.bounds) - NSMinX(frame) - go.intrinsicContentSize.width - 2 * DPCommandBarSpacing);
    text.frame = frame;
}

// Dia labels the buttons after the command bar's first layout. Dictation's label says whether there's chat usage, and if
// that isn't what the command bar went by, it lays out again, along with whatever sizes itself to it.
static void DPCommandBarButton_setAccessibilityLabel(NSView *self, SEL _cmd, NSString *label) {
    DPCallOriginal(DPCommandBarButton_setAccessibilityLabel, self, label);
    NSView *commandBar = self;
    while (commandBar && !DPIsKind(commandBar, DPDiaCommandBar)) commandBar = commandBar.superview;
    NSView *toolbar = DPCommandBarPart(commandBar, DPDiaCommandBarToolbar);
    NSStackView *stack = toolbar.subviews.firstObject;
    if (![stack isKindOfClass:NSStackView.class] || ![stack.views containsObject:self] || self == DPGoButton(toolbar)) return;
    DPRememberChatLocked(DPChatLocked(self));
    if ((DPCompactToolbar(commandBar) != nil) == (DPGet(stack, &DPCompactedKey) != nil)) return;
    for (NSView *view = commandBar; view; view = view.superview) view.needsLayout = YES;
}

// The row now lies over the input, so only Go takes clicks.
static NSView *DPCommandBarToolbar_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    NSView *hit = DPCallOriginal(DPCommandBarToolbar_hitTest, self, point), *commandBar = self.superview.superview;
    if (!hit || !DPIsKind(commandBar, DPDiaCommandBar) || !DPCompactToolbar(commandBar)) return hit;
    return [hit isDescendantOf:DPGoButton(self)] ? hit : nil;
}

void DPInstallCommandBarLayout(void) {
    DPHook(DPDiaPopover, @selector(setFrameSize:), (IMP)DPPopover_setFrameSize);
    DPHook(DPDiaPopover, @selector(setFrameOrigin:), (IMP)DPPopover_setFrameOrigin);
    DPInstallNewTabLayout();
    DPHook(DPDiaCommandBar, @selector(layout), (IMP)DPCommandBar_layout);
    DPHook(DPDiaCommandBarButton, @selector(setAccessibilityLabel:), (IMP)DPCommandBarButton_setAccessibilityLabel);
    DPHook(DPDiaCommandBarInput, @selector(layout), (IMP)DPCommandBarInput_layout);
    DPHook(DPDiaCommandBarToolbar, @selector(hitTest:), (IMP)DPCommandBarToolbar_hitTest);
}
