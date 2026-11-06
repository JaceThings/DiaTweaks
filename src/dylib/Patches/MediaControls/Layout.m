#import "Views.h"

extern DPPatch DPMediaControls;
static NSHashTable<NSView *> *DPSidebars;  // Every sidebar root view Dia has laid out.
static char DPStackViewKey, DPStackKey;
static const CGFloat DPRowInset = 8, DPAboveFooter = 2;

NSHashTable<NSView *> *DPMediaSidebars(void) { return DPSidebars; }

DPMediaStack *DPMediaStackOf(NSWindow *window) {
    DPMediaStack *stack = DPGet(window, &DPStackKey);
    if (!stack && window) DPSet(window, &DPStackKey, stack = [DPMediaStack new]);
    return stack;
}

DPMediaStackView *DPMediaStackViewIn(NSView *sidebar) { return DPGet(sidebar, &DPStackViewKey); }

// The view holding the tab list ends where the footer begins.
static NSView *DPTabListHolder(NSView *sidebar, NSView *footer) {
    for (NSView *view in sidebar.subviews)
        if (view != footer && ![view isKindOfClass:DPMediaStackView.class] && !DPIsKind(view, DPDiaSidebarHeader) && fabs(NSMaxY(view.frame) - NSMinY(footer.frame)) < 80 && NSHeight(view.frame) > 100)
            return view;
    return nil;
}

// Measured from the footer each time, so running again changes nothing.
void DPPlaceMediaStack(NSView *sidebar) {
    NSView *footer = DPSubview(sidebar, DPDiaSidebarFooter), *list = footer ? DPTabListHolder(sidebar, footer) : nil;
    DPMediaStackView *view = DPMediaStackViewIn(sidebar);
    BOOL wanted = DPMediaControls.on && footer && list && sidebar.isFlipped && sidebar.window && [DPTabLayout() isEqual:@"vertical"];
    if (!wanted) {
        if (!view) return;  // Never touched: Dia's own layout stands.
        [view removeFromSuperview];
        DPSet(sidebar, &DPStackViewKey, nil);
        if (list) list.frame = NSMakeRect(NSMinX(list.frame), NSMinY(list.frame), NSWidth(list.frame), NSMinY(footer.frame) - NSMinY(list.frame));
        return;
    }
    if (!view) {
        view = [[DPMediaStackView alloc] initWithFrame:NSZeroRect];
        DPSet(sidebar, &DPStackViewKey, view);
    }
    if (view.stack != DPMediaStackOf(sidebar.window)) {
        view.stack = DPMediaStackOf(sidebar.window);
        [view reload];
    }
    if (view.superview != sidebar) [sidebar addSubview:view positioned:NSWindowAbove relativeTo:list];
    CGFloat rest = view.restHeight, bottom = NSMinY(footer.frame) - (rest ? DPAboveFooter : 0);
    list.frame = NSMakeRect(NSMinX(list.frame), NSMinY(list.frame), NSWidth(list.frame), MAX(0, bottom - rest - NSMinY(list.frame)));
    CGFloat height = view.height;
    view.frame = NSMakeRect(DPRowInset, bottom - height, NSWidth(sidebar.bounds) - 2 * DPRowInset, height);
    view.hidden = height == 0;
}

static void DPSidebar_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPSidebar_viewDidLayout, self);
    [DPSidebars addObject:self.view];
    DPPlaceMediaStack(self.view);
}

void DPInstallMediaLayout(void) {
    DPSidebars = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPSidebar_viewDidLayout);
    [NSNotificationCenter.defaultCenter addObserverForName:DPMediaStackHeightDidChange object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSView *view = note.object;
        if (view.superview) DPPlaceMediaStack(view.superview);
    }];
}
