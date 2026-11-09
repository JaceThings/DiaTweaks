#import "SidebarNavigation.h"

static DPNavigationSlot *DPPlaceToolbarControl(DPNavigationSlot *slot, NSView *toolbar,
                                                 NSView *header, NSView *destination,
                                                 NSArray<NSString *> *labels, NSRect frame) {
    if (NSIsEmptyRect(frame)) {
        DPNavigationRestore(slot);
        return nil;
    }
    if (!slot.view || slot.view.superview != destination) {
        DPNavigationRestore(slot);
        NSView *view = DPFindView(toolbar, ^BOOL(NSView *candidate) {
            return candidate.accessibilityLabel && [labels containsObject:candidate.accessibilityLabel];
        });
        slot = DPNavigationAttach(view,header,destination,frame);
    }
    DPNavigationLayout(slot,frame);
    return slot;
}

BOOL DPPlaceSidebarToggle(DPSidebarNavigationState *state, NSView *destination, NSRect frame) {
    NSString *label = @"Toggle sidebar";
    DPPatch *hide = DPPatchNamed(@"hideSidebarButton");
    if (hide && hide->on) frame = NSZeroRect;
    DPNavigationSlot *slot = DPPlaceToolbarControl(state.toolbarControls[label], state.toolbar,
                                                    destination, destination, @[label], frame);
    state.toolbarControls[label] = slot;
    return slot.view != nil;
}

static void DPRestoreNavigationButtons(DPSidebarNavigationState *state) {
    for (NSString *key in @[@"Reload this page", @"Go forward", @"Go back", @"Downloads", @"Toggle sidebar"])
        DPNavigationRestore(state.toolbarControls[key]);
    [state.toolbarControls removeAllObjects];
}

void DPRestoreSidebarNavigation(DPSidebarNavigationState *state) {
    DPRestoreNavigationButtons(state);
    DPRestoreHorizontalNavigation(state);
    if (state.hiddenProfile) state.hiddenProfile.hidden = state.profileWasHidden;
    state.hiddenProfile = nil;
}

static BOOL DPHeaderControlVisible(NSView *view, NSView *header) {
    for (NSView *ancestor = view; ancestor && ancestor != header; ancestor = ancestor.superview)
        if (ancestor.hidden) return NO;
    return view != nil;
}

void DPPlaceSidebarNavigation(DPSidebarNavigationState *state, NSView *header) {
    NSView *profile = DPFindView(header, ^BOOL(NSView *view) { return DPHasLabel(view,@"Switch between profiles"); });
    NSView *wrapper = profile.superview ?: state.hiddenProfile;
    if (state.hiddenProfile && (state.hiddenProfile != wrapper || !DPSidebarHideProfile.on)) {
        state.hiddenProfile.hidden = state.profileWasHidden;
        state.hiddenProfile = nil;
    }
    if (wrapper && DPSidebarHideProfile.on && !state.hiddenProfile) {
        state.profileWasHidden = wrapper.hidden;
        state.hiddenProfile = wrapper;
    }
    if (state.hiddenProfile && !state.hiddenProfile.hidden) state.hiddenProfile.hidden = YES;
    if (!DPSidebarNavigation.on) { DPRestoreNavigationButtons(state); return; }
    NSView *traffic = DPFindView(header, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaTrafficLights);
    });
    NSView *stack = wrapper.superview ?: traffic.superview;
    // Hide Traffic Lights can detach the lights from the stack. Only visible
    // controls reserve leading space, and an empty header still has room.
    CGFloat start = NSMinX(header.bounds) + 6;
    for (NSView *leading in @[traffic ?: header, profile ?: header]) {
        if (leading == header || !DPHeaderControlVisible(leading, header)) continue;
        start = MAX(start, NSMaxX([header convertRect:leading.bounds fromView:leading]) + 4);
    }
    CGFloat end = NSMaxX(header.bounds) - 6;
    CGFloat slotWidth = 28;
    DPNavigationSlot *downloadSlot = state.toolbarControls[@"Downloads"];
    NSView *downloads = downloadSlot.view ?: DPFindView(header, ^BOOL(NSView *view) {
        return DPIsKind(view,DPDiaDownloadsButton) || DPHasLabel(view,@"Downloads");
    });
    BOOL showDownloads = downloads && (downloadSlot ? !downloadSlot.originalHidden : DPHeaderControlVisible(downloads, header));
    for (NSView *child in stack ? stack.subviews : header.subviews) {
        if (DPNavigationSlotFor(child).owner == header) continue;
        if (child == wrapper || child == downloads || (showDownloads && [downloads isDescendantOf:child] && child.subviews.count == 1)
            || !DPHeaderControlVisible(child, header) || !NSWidth(child.frame)) continue;
        NSRect occupied = [header convertRect:child.bounds fromView:child];
        if (NSMinX(occupied) >= start) end = MIN(end,NSMinX(occupied)-3);
    }
    CGFloat y = round((NSHeight(header.bounds) - 28) / 2);
    NSRect toggleFrame = end - start >= slotWidth ? NSMakeRect(start, y, slotWidth, 28) : NSZeroRect;
    if (DPPlaceSidebarToggle(state, header, toggleFrame)) start += slotWidth;

    if (showDownloads && end-start >= slotWidth) {
        end -= slotWidth;
        NSRect frame = NSMakeRect(end,y,slotWidth,28);
        if (!downloadSlot) downloadSlot = DPNavigationAttach(downloads,header,header,frame);
        DPNavigationLayout(downloadSlot,frame);
        end -= 2;
    } else {
        DPNavigationRestore(downloadSlot);
        downloadSlot = nil;
    }
    state.toolbarControls[@"Downloads"] = downloadSlot;
    NSUInteger capacity = (NSUInteger)floor(MAX(0,end-start)/slotWidth);
    BOOL history = DPSidebarNavigation.on && capacity >= 2;
    BOOL back = DPSidebarNavigation.on && capacity >= 1;
    BOOL reload = DPSidebarNavigation.on && capacity > (history ? 2 : back ? 1 : 0);
    NSArray *labels = @[@[@"Go back"], @[@"Go forward"], @[@"Reload this page",@"Stop loading this page"]];
    NSArray *enabled = @[@(back), @(history), @(reload)];
    CGFloat x = end - slotWidth * (back + history + reload);
    for (NSUInteger i=0; i<labels.count; i++) {
        NSString *key = labels[i][0];
        NSRect frame = [enabled[i] boolValue] ? NSMakeRect(x,y,slotWidth,28) : NSZeroRect;
        state.toolbarControls[key] = DPPlaceToolbarControl(state.toolbarControls[key],state.toolbar,header,header,labels[i],frame);
        if (!NSIsEmptyRect(frame)) x += slotWidth;
    }
}
