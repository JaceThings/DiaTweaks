#import "Canvas.h"
@implementation DPEaselCanvas (KeyboardSelection)
- (BOOL)handleSelectionKey:(NSEvent *)event {
    if(event.keyCode==48) {
        NSArray *objects=[self.document.objects sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [a[@"order"] compare:b[@"order"]]; }];
        if(!objects.count) return YES;
        NSInteger current=-1; for(NSUInteger i=0;i<objects.count;i++) if([self.selection containsObject:objects[i][@"id"]]) { current=i; break; }
        NSInteger next=(current+(event.modifierFlags&NSEventModifierFlagShift ? -1 : 1)+(NSInteger)objects.count)%(NSInteger)objects.count;
        [self.selection setSet:[NSSet setWithObject:objects[next][@"id"]]];
        [self scrollRectToVisible:DPEaselObjectRect(objects[next])]; self.needsDisplay=YES;
        if(self.selectionChanged) self.selectionChanged(); return YES;
    }
    if(event.keyCode==36 && self.selection.count==1) {
        for(NSDictionary *object in self.document.objects) if([self.selection containsObject:object[@"id"]] && [object[@"type"] isEqual:@"text"]) { [self beginText:object]; return YES; }
    }
    if(event.keyCode<123 || event.keyCode>126 || !self.selection.count) return NO;
    CGFloat step=event.modifierFlags&NSEventModifierFlagShift ? 10 : 1;
    CGFloat dx=event.keyCode==123 ? -step : event.keyCode==124 ? step : 0;
    CGFloat dy=event.keyCode==126 ? -step : event.keyCode==125 ? step : 0;
    NSRect group=NSZeroRect; BOOL first=YES;
    for(NSDictionary *object in self.document.objects) if([self.selection containsObject:object[@"id"]]) { group=first ? DPEaselObjectRect(object) : NSUnionRect(group,DPEaselObjectRect(object)); first=NO; }
    dx=MAX(-NSMinX(group),MIN(dx,NSWidth(self.bounds)-NSMaxX(group))); dy=MAX(-NSMinY(group),MIN(dy,NSHeight(self.bounds)-NSMaxY(group)));
    NSMutableArray *objects=[self.document.objects mutableCopy];
    for(NSUInteger i=0;i<objects.count;i++) if([self.selection containsObject:objects[i][@"id"]]) objects[i]=DPEaselTransformObject(objects[i],NSOffsetRect(DPEaselObjectRect(objects[i]),dx,dy));
    [self commit:objects action:@"Nudge"]; return YES;
}
@end
