#import "TaskView.h"
@implementation DPTaskContent (Actions)
- (void)toggleTask:(NSButton *)sender {
    if(!self.allowed || self.removing) return;
    NSString *identifier=sender.identifier; NSDictionary *item=nil;
    for(NSDictionary *candidate in self.store.items) if([candidate[@"id"] isEqual:identifier]) { item=candidate; break; }
    if(!item) return;
    BOOL completed=![item[@"completed"] boolValue];
    if(completed && self.filter==1) [self.pending addObject:identifier]; else [self.pending removeObject:identifier];
    [self.store setCompleted:completed identifier:identifier];
    if(!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        sender.alphaValue=.5;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){ context.duration=.14; sender.animator.alphaValue=1; } completionHandler:nil];
    }
    if(!completed || self.filter!=1) return;
    __weak DPTaskContent *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,140*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ [weak dismissCompletedTask:identifier]; });
}
- (void)dismissCompletedTask:(NSString *)identifier {
    if(![self.pending containsObject:identifier]) return;
    if(self.removing) {
        __weak DPTaskContent *weak=self; dispatch_after(dispatch_time(DISPATCH_TIME_NOW,80*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ [weak dismissCompletedTask:identifier]; }); return;
    }
    BOOL completed=NO; for(NSDictionary *item in self.store.items) if([item[@"id"] isEqual:identifier]) completed=[item[@"completed"] boolValue];
    if(self.filter!=1 || !completed) { [self.pending removeObject:identifier]; [self reload]; return; }
    NSMutableArray *views=NSMutableArray.new;
    if(self.window && !self.hiddenOrHasHiddenAncestor) {
        NSUInteger index=[self.records indexOfObjectPassingTest:^BOOL(NSDictionary *record,NSUInteger idx,BOOL *stop){ return [record[@"id"] isEqual:identifier]; }];
        if(index!=NSNotFound) { NSView *cell=[self.table viewAtColumn:0 row:index makeIfNecessary:NO]; if(cell) [views addObject:cell]; }
    }
    __weak DPTaskContent *weak=self; [self performRemoval:views mutation:^{ [weak.pending removeObject:identifier]; }];
}
- (void)chooseFilter:(NSButton *)sender {
    NSMenu *menu=NSMenu.new; NSArray *names=@[@"All",@"Incomplete",@"Completed",@"Deleted"];
    for(NSUInteger i=0;i<names.count;i++) {
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:names[i] action:@selector(setFilterFromMenu:) keyEquivalent:@""];
        item.target=self; item.tag=i; item.state=self.filter==(NSInteger)i; [menu addItem:item];
    }
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,NSHeight(sender.bounds)) inView:sender];
}
- (void)setFilterFromMenu:(NSMenuItem *)sender { self.filter=[sender isKindOfClass:NSPopUpButton.class] ? [(NSPopUpButton *)sender indexOfSelectedItem] : sender.tag; [self.pending removeAllObjects]; [self reload]; }
- (void)showOptions:(NSButton *)sender {
    NSMenu *menu=NSMenu.new; menu.autoenablesItems=NO;
    NSMenuItem *completed=[[NSMenuItem alloc] initWithTitle:@"Clear All Completed Tasks" action:@selector(clearCompletedTasks:) keyEquivalent:@""];
    completed.target=self; completed.enabled=self.allowed && !self.store.error && [self.store.items indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger i,BOOL *stop){ return [item[@"completed"] boolValue]; }]!=NSNotFound; [menu addItem:completed];
    NSMenuItem *clear=[[NSMenuItem alloc] initWithTitle:@"Clear All Tasks" action:@selector(clearTasks:) keyEquivalent:@""];
    clear.target=self; clear.enabled=self.allowed && self.store.loaded && !self.store.error && self.store.items.count>0; [menu addItem:clear];
    NSMenuItem *restore=[[NSMenuItem alloc] initWithTitle:@"Restore Cleared Tasks" action:@selector(restoreTasks:) keyEquivalent:@""];
    restore.target=self; restore.enabled=self.allowed && self.store.cleared.count>0 && !self.store.error; [menu addItem:restore];
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,NSHeight(sender.bounds)) inView:sender];
}
- (void)clearTasks:(id)sender {
    if(!self.allowed || self.removing) return;
    DPTaskStore *store=self.store; [self.pending removeAllObjects];
    [self performRemoval:self.records.count ? @[self.table] : @[] mutation:^{ [store clear]; }];
}
- (void)clearCompletedTasks:(id)sender {
    if(!self.allowed || self.removing) return;
    NSMutableArray *views=NSMutableArray.new;
    for(NSUInteger i=0;i<self.records.count;i++) if([self.records[i][@"completed"] boolValue]) { NSView *cell=[self.table viewAtColumn:0 row:i makeIfNecessary:NO]; if(cell) [views addObject:cell]; }
    DPTaskStore *store=self.store; [self.pending removeAllObjects]; [self performRemoval:views mutation:^{ [store clearCompleted]; }];
}
- (void)restoreTasks:(id)sender { if(self.allowed) [self.store restoreCleared]; }
@end
