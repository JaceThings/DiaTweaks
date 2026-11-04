#import "CompactSidebar.h"

// In the strip a folder shows as its icon, centered, with its tabs under it at the strip's width. Dia would squeeze the
// folder's name, arrow and close button in beside the icon, and indent its tabs past the strip's edge.

static BOOL DPListInStrip(NSCollectionViewLayout *layout) {
    NSCollectionView *list = layout.collectionView;
    return list && DPStripPresent(list.window) && NSWidth(list.bounds) <= DPStripWidth + DPRevealRoom(list.window) + 0.5;
}

// A copy, since the layout keeps its own for the next pass.
static NSCollectionViewLayoutAttributes *DPUnindented(NSCollectionViewLayout *layout, NSCollectionViewLayoutAttributes *attributes) {
    if (!attributes || NSMinX(attributes.frame) <= 0 || !DPListInStrip(layout)) return attributes;
    NSCollectionViewLayoutAttributes *flat = [attributes copy];
    flat.frame = NSMakeRect(0, NSMinY(attributes.frame), NSWidth(layout.collectionView.bounds), NSHeight(attributes.frame));
    return flat;
}

static NSArray *DPLayout_elementsInRect(NSCollectionViewLayout *self, SEL _cmd, NSRect rect) {
    NSArray<NSCollectionViewLayoutAttributes *> *attributes = DPCallOriginal(DPLayout_elementsInRect, self, rect);
    if (!DPListInStrip(self)) return attributes;
    NSMutableArray *flat = [NSMutableArray arrayWithCapacity:attributes.count];
    for (NSCollectionViewLayoutAttributes *each in attributes) [flat addObject:DPUnindented(self, each)];
    return flat;
}

static id DPLayout_item(NSCollectionViewLayout *self, SEL _cmd, NSIndexPath *path) {
    return DPUnindented(self, DPCallOriginal(DPLayout_item, self, path));
}

static id DPLayout_appearing(NSCollectionViewLayout *self, SEL _cmd, NSIndexPath *path) {
    return DPUnindented(self, DPCallOriginal(DPLayout_appearing, self, path));
}

static id DPLayout_disappearing(NSCollectionViewLayout *self, SEL _cmd, NSIndexPath *path) {
    return DPUnindented(self, DPCallOriginal(DPLayout_disappearing, self, path));
}

static char DPStripHiddenKey, DPFolderBoxKey;
static const CGFloat DPFolderBoxAlpha = 0.06;

// Dia fades the header's extras in as the pointer comes near; while the strip hides them, they stay out of sight.
static void DPExtra_setAlphaValue(NSView *self, SEL _cmd, CGFloat alpha) {
    DPCallOriginal(DPExtra_setAlphaValue, self, [DPGet(self, &DPStripHiddenKey) boolValue] ? 0 : alpha);
}

// Nor do they take clicks: the close button Dia shows under the pointer overlaps the folder's icon in the strip, where a
// click would close the folder instead of opening it. Closing it is still in the folder's menu.
static NSView *DPExtra_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    return [DPGet(self, &DPStripHiddenKey) boolValue] ? nil : DPCallOriginal(DPExtra_hitTest, self, point);
}

static void DPHideExtra(NSView *view, BOOL hide) {
    if (hide) {
        DPHookClass(view.class, @selector(setAlphaValue:), (IMP)DPExtra_setAlphaValue);
        DPHookClass(view.class, @selector(hitTest:), (IMP)DPExtra_hitTest);
    }
    if ([DPGet(view, &DPStripHiddenKey) boolValue] == hide) return;
    DPSet(view, &DPStripHiddenKey, @(hide));
    view.alphaValue = hide ? 0 : 1;
}

// Dia draws the folder's box only under the pointer; in the strip, where its name doesn't show, a faint box always
// shows which tabs are in it.
static void DPPlaceFolderBox(NSView *folder, BOOL strip) {
    NSView *box = DPGet(folder, &DPFolderBoxKey), *dia = folder.subviews.firstObject;
    if (strip && !box) {
        DPSet(folder, &DPFolderBoxKey, box = [NSView new]);
        box.wantsLayer = YES;
        box.layer.cornerRadius = dia.layer.cornerRadius ?: 10;
    }
    box.hidden = !strip;
    if (!strip) return;
    if (folder.subviews.firstObject != box) [folder addSubview:box positioned:NSWindowBelow relativeTo:nil];
    NSRect frame = dia && dia != box ? dia.frame : NSInsetRect(folder.bounds, 6, 1.5);
    if (!NSEqualRects(box.frame, frame)) DPNow(^{ box.frame = frame; });
    [folder.effectiveAppearance performAsCurrentDrawingAppearance:^{
        box.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:DPFolderBoxAlpha].CGColor;
    }];
}

// The folder's header row: its icon stays, centered; its name, arrow and close button give way. A click still opens and
// closes the folder.
static void DPGroup_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGroup_layout, self);
    BOOL strip = DPStripPresent(self.window) && NSWidth(self.bounds) <= DPStripWidth + DPRevealRoom(self.window) + 0.5;
    DPPlaceFolderBox(self, strip);
    NSView *header = DPSubview(self, DPDiaFlippedView);
    for (NSView *sub in header.subviews) {
        if (!DPIsKind(sub, DPDiaFlippedView)) {
            DPHideExtra(sub, strip);
            continue;
        }
        CGFloat x = round((NSWidth(header.bounds) - NSWidth(sub.frame)) / 2);  // The folder's icon.
        if (strip && NSMinX(sub.frame) != x) DPNow(^{ [sub setFrameOrigin:NSMakePoint(x, NSMinY(sub.frame))]; });
    }
}

void DPInstallCompactFolders(void) {
    DPHook(DPDiaTabListLayout, @selector(layoutAttributesForElementsInRect:), (IMP)DPLayout_elementsInRect);
    DPHook(DPDiaTabListLayout, @selector(layoutAttributesForItemAtIndexPath:), (IMP)DPLayout_item);
    DPHook(DPDiaTabListLayout, @selector(initialLayoutAttributesForAppearingItemAtIndexPath:), (IMP)DPLayout_appearing);
    DPHook(DPDiaTabListLayout, @selector(finalLayoutAttributesForDisappearingItemAtIndexPath:), (IMP)DPLayout_disappearing);
    DPHook(DPDiaTabGroupCell, @selector(layout), (IMP)DPGroup_layout);
}
