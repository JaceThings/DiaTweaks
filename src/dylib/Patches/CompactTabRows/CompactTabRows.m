#import "StdPatch/StdPatch.h"

// Dia 1.57 made the sidebar's rows 41 pt tall, from 37. After Dia lays the list out, each row of the usual height gives
// back the difference: the rows below move up, and a folder shrinks by its own header and the rows inside it.

extern DPPatch DPCompactTabRows;

static const CGFloat DPOldRowHeight = 37;

static void DPRelayoutTabList(void) {
    for (NSView *view in DPFindViews(DPDiaTabListCollection)) [((NSCollectionView *)view).collectionViewLayout invalidateLayout];
}

// The most common item height is a row's. Nothing to do when rows are already the old height, or a kept layout still has ours.
static CGFloat DPRowHeight(NSArray<NSCollectionViewLayoutAttributes *> *all) {
    NSCountedSet<NSNumber *> *heights = [NSCountedSet set];
    for (NSCollectionViewLayoutAttributes *a in all)
        if (a.representedElementCategory == NSCollectionElementCategoryItem) [heights addObject:@(round(NSHeight(a.frame) * 2) / 2)];
    NSNumber *row = nil;
    for (NSNumber *each in heights) if (!row || [heights countForObject:each] > [heights countForObject:row]) row = each;
    return row.doubleValue;
}

static void DPLayout_prepareLayout(NSCollectionViewLayout *self, SEL _cmd) {
    DPCallOriginal(DPLayout_prepareLayout, self);
    if (!DPCompactTabRows.on) return;
    double *contentHeight = DPIvar(self, "contentHeight");  // Dia's layout hands out the attributes it keeps, so changing them changes it.
    NSArray<NSCollectionViewLayoutAttributes *> *all = [self layoutAttributesForElementsInRect:NSMakeRect(-1e5, -1e5, 2e5, 1e7)];
    CGFloat height = DPRowHeight(all), cut = height - DPOldRowHeight;
    if (!contentHeight || cut < 0.5) return;
    // A row is an item of the row height, or the header at the top of anything taller, such as an open folder.
    NSMutableArray<NSValue *> *rows = [NSMutableArray new];
    for (NSCollectionViewLayoutAttributes *a in all)
        if (a.representedElementCategory == NSCollectionElementCategoryItem && NSHeight(a.frame) >= height - 0.5)
            [rows addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(a.frame), NSMinY(a.frame), NSWidth(a.frame), height)]];
    for (NSCollectionViewLayoutAttributes *a in all) {
        NSRect frame = a.frame;
        for (NSValue *value in rows) {
            NSRect row = value.rectValue;
            // A folder's first row starts 3 pt up into its header.
            if (NSMaxY(row) <= NSMinY(a.frame) + 3.5) frame.origin.y -= cut;
            else if (NSMinY(row) >= NSMinY(a.frame) - 0.5 && NSMaxY(row) <= NSMaxY(a.frame) + 0.5) frame.size.height -= cut;
        }
        a.frame = frame;
    }
    *contentHeight -= cut * rows.count;
}

// An open folder lays its header out at the new height, so its title would sit low over the shorter header. It moves up
// to the middle of the old one.
static void DPGroupCell_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGroupCell_layout, self);
    if (!DPCompactTabRows.on || NSHeight(self.bounds) <= DPOldRowHeight + 0.5) return;
    for (NSView *header in self.subviews) {
        CGFloat extra = NSHeight(header.frame) - (DPOldRowHeight - 3);
        if (!DPIsKind(header, DPDiaTabGroupBackground) && extra > 0.5 && extra < 4.5 && NSMinY(header.frame) > 1)
            [header setFrameOrigin:NSMakePoint(NSMinX(header.frame), NSMinY(header.frame) - extra / 2)];
    }
}

static void DPInstallCompactTabRows(void) {
    DPHook(DPDiaTabListLayout, @selector(prepareLayout), (IMP)DPLayout_prepareLayout);
    DPHook(DPDiaTabGroupCell, @selector(layout), (IMP)DPGroupCell_layout);
}

static void DPApplyCompactTabRows(DPPatch *patch) { DPRelayoutTabList(); }

static NSString *DPVerifyCompactTabRows(DPPatch *patch) {
    for (NSView *view in DPFindViews(DPDiaTabListCollection)) {
        NSArray *all = [((NSCollectionView *)view).collectionViewLayout layoutAttributesForElementsInRect:NSMakeRect(-1e5, -1e5, 2e5, 1e7)];
        if (patch->on && DPRowHeight(all) > DPOldRowHeight + 0.5) return @"tab rows are taller than 37 pt";
    }
    return nil;
}

DP_PATCH(DPCompactTabRows) {
    .key = @"compactTabRows",
    .order = 77,
    .section = @"Sidebar & Tab Bar",
    .title = @"Compact Tab Rows",
    .detail = @"Make the sidebar's tabs and folders as short as before Dia 1.57, so more fit.",
    .symbol = @"rectangle.compress.vertical",
    .tint = @"systemTealColor",
    .classes = DPClasses(DPDiaTabListLayout, DPDiaTabListCollection, DPDiaTabGroupCell, DPDiaTabGroupBackground),
    .install = DPInstallCompactTabRows,
    .apply = DPApplyCompactTabRows,
    .verify = DPVerifyCompactTabRows,
};
