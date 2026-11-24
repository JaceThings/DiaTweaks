#import "Canvas.h"
@implementation DPEaselCanvas (DuplicateDrag)
- (void)beginDuplicateDrag {
    if(self.duplicatingSelection || !self.moving || !self.selection.count) return;
    self.dragSelection=self.selection.copy;
    NSMutableArray *objects=[self.initialObjects mutableCopy]; NSMutableSet *copies=NSMutableSet.new;
    NSUInteger order=0; for(NSDictionary *object in objects) order=MAX(order,[object[@"order"] unsignedIntegerValue]+1);
    for(NSDictionary *object in self.initialObjects) if([self.selection containsObject:object[@"id"]]) {
        NSMutableDictionary *copy=[object mutableCopy]; [copy removeObjectForKey:@"isTitle"];
        copy[@"id"]=NSUUID.UUID.UUIDString; copy[@"order"]=@(order); copy[@"z"]=@(order++);
        [objects addObject:copy]; [copies addObject:copy[@"id"]];
    }
    self.dragObjects=objects; self.selection=copies; self.duplicatingSelection=YES;
}
@end
