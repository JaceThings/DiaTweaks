#import "Library.h"
static char DPLibraryStripKey;
@interface DPLibraryStripState : NSObject
@property NSButton *button;
@property NSMapTable<NSView *,NSValue *> *frames,*applied;
@end
@implementation DPLibraryStripState @end
static void DPRestoreLibraryStrip(NSView *strip) {
    DPLibraryStripState *state = DPGet(strip,&DPLibraryStripKey);
    for (NSView *view in state.frames) {
        NSRect saved=[state.frames objectForKey:view].rectValue;
        if([NSStringFromClass(view.class) containsString:@"FeatheredContainerView"]) {
            // We reserve horizontal space only. A native layout can finish
            // sizing this clipping view after our first zero-height snapshot.
            NSRect live=view.frame,applied=[state.applied objectForKey:view].rectValue;
            if(fabs(live.origin.x-applied.origin.x)<.01 && fabs(live.size.width-applied.size.width)<.01) { live.origin.x=saved.origin.x; live.size.width=saved.size.width; }
            view.frame=live;
        } else if(NSEqualRects(view.frame,[state.applied objectForKey:view].rectValue)) view.frame=saved;
    }
    [state.frames removeAllObjects]; [state.applied removeAllObjects];
}
static void DPPlaceLibraryStrip(NSView *strip) {
    DPLibraryStripState *state = DPGet(strip,&DPLibraryStripKey);
    BOOL vertical = DPFindView(strip.window.contentView,^BOOL(NSView *view) { return DPIsKind(view,DPDiaSidebarFooter); }) != nil;
    if (!DPSidebarLibrary.on || !strip.window || vertical || NSWidth(strip.bounds)<200) {
        [state.button removeFromSuperview]; DPSet(strip,&DPLibraryStripKey,nil); return;
    }
    if (!state) {
        state = [DPLibraryStripState new]; state.frames = [NSMapTable weakToStrongObjectsMapTable]; state.applied=[NSMapTable weakToStrongObjectsMapTable];
        state.button = DPLibraryMakeEntryButton(@"DiaTweaks.SidebarLibrary.HorizontalButton");
        DPSet(strip,&DPLibraryStripKey,state); [strip addSubview:state.button];
    }
    NSMutableArray<NSView *> *controls = [NSMutableArray new];
    for (NSView *view in strip.subviews) {
        if (view == state.button || view.hidden || NSWidth(view.frame)<16 || NSWidth(view.frame)>48 || NSHeight(view.frame)>44) continue;
        if (NSMinX(view.frame)<NSWidth(strip.bounds)/2) continue;
        if ([NSStringFromClass(view.class) containsString:@"Button"]) [controls addObject:view];
    }
    [controls sortUsingComparator:^NSComparisonResult(NSView *a,NSView *b) { return NSMinX(a.frame)<NSMinX(b.frame) ? NSOrderedAscending : NSOrderedDescending; }];
    NSUInteger insertion = [controls indexOfObjectPassingTest:^BOOL(NSView *view,NSUInteger index,BOOL *stop) { return DPIsKind(view,DPDiaLibraryButton); }];
    [controls insertObject:state.button atIndex:insertion == NSNotFound ? 0 : insertion];
    CGFloat x = NSWidth(strip.bounds)-38;
    // Native trailing controls keep their order; Library precedes Pages/Chats.
    for (NSView *view in controls.reverseObjectEnumerator) {
        if (view != state.button) [state.frames setObject:@(view.frame) forKey:view];
        view.frame = NSMakeRect(x,5,32,32); [state.applied setObject:@(view.frame) forKey:view]; x -= 42;
    }
    CGFloat viewportEnd = x+42;
    for (NSView *view in strip.subviews) {
        if (![NSStringFromClass(view.class) containsString:@"FeatheredContainerView"]) continue;
        [state.frames setObject:@(view.frame) forKey:view];
        NSRect frame = view.frame; frame.size.width = MAX(0,viewportEnd-8-NSMinX(frame)); view.frame = frame; [state.applied setObject:@(frame) forKey:view];
    }
}
static void DPLibraryStripLayout(NSView *self,SEL _cmd) {
    DPRestoreLibraryStrip(self); DPCallOriginal(DPLibraryStripLayout,self); DPRestoreLibraryStrip(self); DPPlaceLibraryStrip(self);
}
static void DPLibraryStripAttached(NSView *self,SEL _cmd) {
    DPRestoreLibraryStrip(self); DPCallOriginal(DPLibraryStripAttached,self); DPRestoreLibraryStrip(self); DPPlaceLibraryStrip(self);
}
void DPLibraryInstallHorizontal(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:@"DPSidebarNavigationWillLayoutStrip" object:nil queue:nil usingBlock:^(NSNotification *note) { DPRestoreLibraryStrip(note.object); }];
    [NSNotificationCenter.defaultCenter addObserverForName:@"DPSidebarNavigationDidLayoutStrip" object:nil queue:nil usingBlock:^(NSNotification *note) { DPPlaceLibraryStrip(note.object); }];
    DPHook(DPDiaTabStrip,@selector(layout),(IMP)DPLibraryStripLayout);
    DPHook(DPDiaTabStrip,@selector(viewDidMoveToWindow),(IMP)DPLibraryStripAttached);
}
void DPLibraryRefreshHorizontal(void) {
    for (NSView *strip in DPFindViews(DPDiaTabStrip)) { DPRestoreLibraryStrip(strip); strip.needsLayout = YES; [strip layoutSubtreeIfNeeded]; }
}

NSString *DPLibraryVerifyHorizontal(BOOL enabled) {
    for (NSView *strip in DPFindViews(DPDiaTabStrip)) {
        if (strip.hiddenOrHasHiddenAncestor || NSWidth(strip.bounds)<200) continue;
        BOOL vertical = DPFindView(strip.window.contentView,^BOOL(NSView *v) { return DPIsKind(v,DPDiaSidebarFooter); }) != nil;
        NSView *button = DPFindView(strip,^BOOL(NSView *v) { return [v.identifier isEqual:@"DiaTweaks.SidebarLibrary.HorizontalButton"]; });
        if ((!enabled || vertical) && button) return @"horizontal Library entry remains while unavailable";
        if (!enabled || vertical) continue;
        if (!button) return @"horizontal Library entry is missing";
        if (NSMinX(button.frame)<0 || NSMaxX(button.frame)>NSWidth(strip.bounds)) return @"horizontal Library entry is outside the header";
        for (NSView *view in strip.subviews) {
            if (view==button || view.hiddenOrHasHiddenAncestor || NSMinX(view.frame)<NSWidth(strip.bounds)/2 || NSWidth(view.frame)>48) continue;
            if ([NSStringFromClass(view.class) containsString:@"Button"] && NSIntersectsRect(view.frame,button.frame)) return @"horizontal Library entry overlaps a native button";
        }
    }
    return nil;
}
