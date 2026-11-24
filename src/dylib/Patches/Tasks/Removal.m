#import "TaskView.h"
@implementation DPTaskContent (Removal)
- (void)performRemoval:(NSArray<NSView *> *)views mutation:(void (^)(void))mutation {
    if(self.removing || !self.allowed) return;
    self.removing=YES; self.filterButton.enabled=NO;
    NSMutableArray *alpha=NSMutableArray.new; for(NSView *view in views) [alpha addObject:@(view.alphaValue)];
    __weak DPTaskContent *weak=self;
    DPLibraryDissolve(views,^{
        for(NSUInteger i=0;i<views.count;i++) views[i].alphaValue=[alpha[i] doubleValue];
        mutation();
        DPTaskContent *owner=weak; owner.removing=NO; owner.filterButton.enabled=YES;
        owner.animateReflow=DPSidebarLibraryDust.on && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
        [owner reload];
    });
}
@end
void DPTasksAnimateRows(NSTableView *table,NSArray *old,NSArray *current) {
    if(old.count<=current.count) return;
    NSMutableDictionary *indexes=NSMutableDictionary.new;
    for(NSUInteger i=0;i<old.count;i++) indexes[old[i][@"id"]]=@(i);
    [table layoutSubtreeIfNeeded];
    for(NSUInteger i=0;i<current.count;i++) {
        NSNumber *previous=indexes[current[i][@"id"]]; if(!previous || previous.unsignedIntegerValue==i) continue;
        NSView *row=[table rowViewAtRow:i makeIfNecessary:NO]; if(!row) continue;
        row.wantsLayer=YES; CGFloat delta=(previous.integerValue-(NSInteger)i)*(table.rowHeight+table.intercellSpacing.height);
        CABasicAnimation *move=[CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        move.fromValue=@(delta); move.toValue=@0; move.duration=.18;
        move.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [row.layer addAnimation:move forKey:@"taskReflow"];
    }
}
