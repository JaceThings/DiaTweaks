#import "StoreInternal.h"
@implementation DPTaskStore (Editing)
- (void)edit:(NSString *)text identifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread,@"Tasks mutate on main");
    text=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!self.loaded || self.error || !text.length || text.length>4096) return;
    NSMutableArray *items=[self.items mutableCopy];
    NSUInteger index=[items indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger i,BOOL *stop){ return [item[@"id"] isEqual:identifier]; }];
    if(index==NSNotFound || [items[index][@"text"] isEqual:text]) return;
    NSMutableDictionary *item=[items[index] mutableCopy]; item[@"text"]=text; items[index]=item; self.items=items; [self save];
}
- (void)remove:(NSString *)identifier {
    if(!self.loaded || self.error || self.items.count+self.cleared.count>50000) return;
    NSMutableArray *items=[self.items mutableCopy];
    NSUInteger index=[items indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger i,BOOL *stop){ return [item[@"id"] isEqual:identifier]; }];
    if(index==NSNotFound) return;
    self.cleared=[DPTasksDeleted(@[items[index]],NSDate.date.timeIntervalSince1970) arrayByAddingObjectsFromArray:self.cleared]; [items removeObjectAtIndex:index]; self.items=items; [self save];
}
- (void)restore:(NSString *)identifier {
    if(!self.loaded || self.error || self.items.count+self.cleared.count>50000) return;
    NSMutableArray *items=[self.cleared mutableCopy];
    NSUInteger index=[items indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger i,BOOL *stop){ return [item[@"id"] isEqual:identifier]; }];
    if(index==NSNotFound) return;
    self.items=[DPTasksRestored(@[items[index]]) arrayByAddingObjectsFromArray:self.items]; [items removeObjectAtIndex:index]; self.cleared=items; [self save];
}
- (void)clearCompleted {
    if(!self.loaded || self.error || self.items.count+self.cleared.count>50000) return;
    NSArray *completed=[self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,id bindings){ return [item[@"completed"] boolValue]; }]];
    if(!completed.count) return;
    self.cleared=[DPTasksDeleted(completed,NSDate.date.timeIntervalSince1970) arrayByAddingObjectsFromArray:self.cleared];
    self.items=[self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,id bindings){ return ![item[@"completed"] boolValue]; }]]; [self save];
}
@end
