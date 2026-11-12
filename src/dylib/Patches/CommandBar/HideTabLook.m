#import "Patches/CommandBar/HideTab.h"

static char DPRowLookKey, DPStripLookKey;
static NSArray *DPLastRowLook, *DPLastStripLook;

// A selection style below this is one of its cases without a fill, such as not selected.
const uintptr_t DPFirstFill = 1 << 16;

NSView *DPIvarView(NSView *view, const char *name) {
    void **storage = DPIvar(view, name);
    return storage ? (__bridge NSView *)*storage : nil;
}

uintptr_t *DPSelectionStyle(NSView *background) { return DPIvar(background, "selectionStyle"); }
NSView *DPTabShapeView(NSView *background) { return DPIvarView(background, "$__lazy_storage_$_tabShapeView"); }
uint8_t *DPTabShape(NSView *background) { return DPIvar(DPTabShapeView(background), "shape"); }
BOOL DPDrawnSelected(NSView *background) { return DPSelectionStyle(background) && *DPSelectionStyle(background) >= DPFirstFill; }

BOOL DPInStrip(NSView *view) {
    while (view && !DPIsKind(view, DPDiaTabStripTabs)) view = view.superview;
    return view != nil;
}

// The selected tab's fill, which follows the space's theme, and shape, kept as Dia draws it, for the sidebar and the
// strip apart. The bar opens while the new tab is in front, and a favorite in front has no tab to take them from.
void DPNoteLook(NSView *background) {
    if (!DPIsKind(background.superview, DPDiaTabView) || !DPDrawnSelected(background) || !DPTabShape(background) || !background.window) return;
    id fill = (__bridge id)(void *)*DPSelectionStyle(background);
    if (![fill isKindOfClass:NSColor.class]) return;
    BOOL strip = DPInStrip(background);
    NSArray *look = @[ fill, @(*DPTabShape(background)) ];
    DPSet(background.window, strip ? &DPStripLookKey : &DPRowLookKey, look);
    *(strip ? &DPLastStripLook : &DPLastRowLook) = look;
}

NSArray *DPSelectedLook(NSView *button) {
    BOOL strip = DPInStrip(button);
    return DPGet(button.window, strip ? &DPStripLookKey : &DPRowLookKey) ?: (strip ? DPLastStripLook : DPLastRowLook);
}
