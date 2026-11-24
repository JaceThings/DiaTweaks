#import "Canvas.h"
@implementation DPEaselCanvas (SelectionActions)
- (void)delete:(id)sender {
    [self endText];
    NSArray *objects=[self.document.objects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *object,id bindings){ return ![self.selection containsObject:object[@"id"]]; }]];
    [self commit:objects action:@"Delete Objects"]; [self.selection removeAllObjects];
}
- (void)selectAll:(id)sender { [self.selection setSet:[NSSet setWithArray:[self.document.objects valueForKey:@"id"]]]; self.needsDisplay=YES; if(self.selectionChanged) self.selectionChanged(); }
- (void)duplicate:(id)sender {
    [self endText]; NSMutableArray *objects=[self.document.objects mutableCopy]; NSMutableSet *selected=NSMutableSet.new;
    NSUInteger order=0; for(NSDictionary *object in objects) order=MAX(order,[object[@"order"] unsignedIntegerValue]+1);
    for(NSDictionary *object in self.document.objects) if([self.selection containsObject:object[@"id"]]) {
        NSRect frame=NSOffsetRect(DPEaselObjectRect(object),16,16);
        frame.origin.x=MAX(0,MIN(frame.origin.x,NSWidth(self.bounds)-frame.size.width)); frame.origin.y=MAX(0,MIN(frame.origin.y,NSHeight(self.bounds)-frame.size.height));
        NSMutableDictionary *copy=[DPEaselTransformObject(object,frame) mutableCopy];
        [copy removeObjectForKey:@"isTitle"];
        copy[@"id"]=NSUUID.UUID.UUIDString; copy[@"order"]=@(order); copy[@"z"]=@(order++);
        [objects addObject:copy]; [selected addObject:copy[@"id"]];
    }
    [self commit:objects action:@"Duplicate"]; self.selection=selected; self.needsDisplay=YES;
}
- (void)reorder:(BOOL)front {
    double edge=0; for(NSDictionary *object in self.document.objects) edge=front ? MAX(edge,[object[@"z"] doubleValue]) : MIN(edge,[object[@"z"] doubleValue]);
    NSMutableArray *objects=[self.document.objects mutableCopy];
    for(NSUInteger i=0;i<objects.count;i++) if([self.selection containsObject:objects[i][@"id"]]) {
        NSMutableDictionary *object=[objects[i] mutableCopy]; edge+=front ? 1 : -1; object[@"z"]=@(edge); objects[i]=object;
    }
    [self commit:objects action:front ? @"Bring to Front" : @"Send to Back"];
}
- (void)bringToFront:(id)sender { [self reorder:YES]; }
- (void)sendToBack:(id)sender { [self reorder:NO]; }
@end
