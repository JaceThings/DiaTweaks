#import "Canvas.h"
@implementation DPEaselCanvas (SelectionDrag)
- (void)updateSelectionDrag:(NSPoint)point modifiers:(NSEventModifierFlags)modifiers {
    NSMutableArray *objects=[(self.dragObjects ?: self.initialObjects) mutableCopy],*neighbors=NSMutableArray.new;
    NSRect group=NSZeroRect; BOOL first=YES;
    for(NSDictionary *object in objects) {
        NSRect rect=DPEaselObjectRect(object);
        if([self.selection containsObject:object[@"id"]]) { group=first ? rect : NSUnionRect(group,rect); first=NO; }
        else if(NSIntersectsRect(rect,self.visibleRect)) [neighbors addObject:[NSValue valueWithRect:rect]];
    }
    if(first) return;
    if(self.cropping) {
        for(NSUInteger i=0;i<objects.count;i++) if([self.selection containsObject:objects[i][@"id"]]) objects[i]=DPEaselCropImage(objects[i],point,self.cropEdges,self.resizeGrabOffset,self.bounds);
    } else if(self.resizing>=0) {
        point.x-=self.resizeGrabOffset.x; point.y-=self.resizeGrabOffset.y;
        for(NSUInteger i=0;i<objects.count;i++) if([self.selection containsObject:objects[i][@"id"]])
            objects[i]=[self resizeObject:objects[i] toPoint:point modifiers:modifiers neighbors:neighbors];
    } else {
        NSRect proposed=NSOffsetRect(group,point.x-self.origin.x,point.y-self.origin.y);
        proposed.origin.x=MAX(0,MIN(proposed.origin.x,NSWidth(self.bounds)-proposed.size.width));
        proposed.origin.y=MAX(0,MIN(proposed.origin.y,NSHeight(self.bounds)-proposed.size.height));
        CGFloat unit=DPEaselScreenUnit(self);
        NSDictionary *snap=DPEaselSnapWithin(proposed,neighbors,self.bounds.size,modifiers&NSEventModifierFlagOption,4*unit);
        NSRect aligned=[snap[@"rect"] rectValue];
        NSMutableArray *guides=[snap[@"guides"] mutableCopy];
        // Keep a guide only within seven points, then release without resistance.
        if(!(modifiers&NSEventModifierFlagOption)) for(NSDictionary *guide in self.guides) {
            NSUInteger axis=[guide[@"axis"] unsignedIntegerValue]; CGFloat target=[guide[@"position"] doubleValue];
            NSArray *anchors=axis ? @[@(NSMinY(proposed)),@(NSMidY(proposed)),@(NSMaxY(proposed))] : @[@(NSMinX(proposed)),@(NSMidX(proposed)),@(NSMaxX(proposed))];
            CGFloat best=7.01*unit,delta=0;
            for(NSNumber *anchor in anchors) if(fabs(target-anchor.doubleValue)<best) { best=fabs(target-anchor.doubleValue); delta=target-anchor.doubleValue; }
            if(best>7*unit) continue;
            NSIndexSet *sameAxis=[guides indexesOfObjectsPassingTest:^BOOL(NSDictionary *value,NSUInteger index,BOOL *stop){ return [value[@"axis"] unsignedIntegerValue]==axis; }];
            [guides removeObjectsAtIndexes:sameAxis]; [guides addObject:guide];
            if(axis) aligned.origin.y=proposed.origin.y+delta; else aligned.origin.x=proposed.origin.x+delta;
        }
        self.guides=guides;
        for(NSUInteger i=0;i<objects.count;i++) if([self.selection containsObject:objects[i][@"id"]]) {
            NSRect old=DPEaselObjectRect(objects[i]);
            objects[i]=DPEaselTransformObject(objects[i],NSOffsetRect(old,aligned.origin.x-group.origin.x,aligned.origin.y-group.origin.y));
        }
    }
    self.previewObjects=objects;
}
@end
