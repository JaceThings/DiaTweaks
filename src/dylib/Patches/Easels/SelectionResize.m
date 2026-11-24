#import "Canvas.h"
@implementation DPEaselCanvas (SelectionResize)
- (NSDictionary *)resizeObject:(NSDictionary *)object toPoint:(NSPoint)point modifiers:(NSEventModifierFlags)modifiers neighbors:(NSArray<NSValue *> *)neighbors {
    CGFloat unit=DPEaselScreenUnit(self);
    BOOL arrow=[object[@"type"] isEqual:@"arrow"],image=[object[@"type"] isEqual:@"image"];
    NSArray *handles=DPEaselSelectionHandles(object);
    NSUInteger opposite=arrow ? (self.resizing==0 ? 1 : 0) : (self.resizing+2)%4;
    NSPoint anchor=[handles[opposite] pointValue];
    BOOL constrained=image || (modifiers&NSEventModifierFlagShift);
    if(!constrained) {
        NSDictionary *snap=DPEaselSnapWithin(NSMakeRect(point.x,point.y,0,0),neighbors,self.bounds.size,
            modifiers&NSEventModifierFlagOption,4*unit);
        point=[snap[@"rect"] rectValue].origin; self.guides=snap[@"guides"];
    } else self.guides=nil;
    point.x=MAX(0,MIN(NSWidth(self.bounds),point.x)); point.y=MAX(0,MIN(NSHeight(self.bounds),point.y));
    NSMutableDictionary *result=[object mutableCopy];
    if(arrow) {
        if(modifiers&NSEventModifierFlagShift) point=DPEaselStraightEnd(anchor,point);
        CGFloat dx=point.x-anchor.x,dy=point.y-anchor.y,fit=1;
        if(dx>0) fit=MIN(fit,(NSWidth(self.bounds)-anchor.x)/dx); else if(dx<0) fit=MIN(fit,-anchor.x/dx);
        if(dy>0) fit=MIN(fit,(NSHeight(self.bounds)-anchor.y)/dy); else if(dy<0) fit=MIN(fit,-anchor.y/dy);
        point=NSMakePoint(anchor.x+dx*fit,anchor.y+dy*fit);
        if(hypot(point.x-anchor.x,point.y-anchor.y)<4*unit) return object;
        NSArray *fixed=@[@(anchor.x),@(anchor.y)],*moving=@[@(point.x),@(point.y)];
        result[@"points"]=self.resizing==0 ? @[moving,fixed] : @[fixed,moving];
        NSRect frame=DPEaselDragRect(anchor,point,NO); frame.size.width=MAX(1,frame.size.width); frame.size.height=MAX(1,frame.size.height);
        result[@"rect"]=DPEaselRectArray(frame); return result;
    }
    // Keep the opposite corner fixed and stop at the minimum instead of
    // flipping the object when a dragged handle crosses its anchor.
    NSRect old=DPEaselObjectRect(object);
    CGFloat sx=(self.resizing==0 || self.resizing==3) ? -1 : 1;
    CGFloat sy=self.resizing<2 ? -1 : 1;
    CGFloat width=MAX(4,sx*(point.x-anchor.x)),height=MAX(4,sy*(point.y-anchor.y));
    CGFloat maxWidth=sx<0 ? anchor.x : NSWidth(self.bounds)-anchor.x;
    CGFloat maxHeight=sy<0 ? anchor.y : NSHeight(self.bounds)-anchor.y;
    if(constrained) {
        CGFloat ratio=image ? old.size.width/MAX(1,old.size.height) : 1;
        width=MAX(width,height*ratio); height=width/ratio;
        CGFloat fit=MIN(1,MIN(maxWidth/MAX(1,width),maxHeight/MAX(1,height)));
        width*=fit; height*=fit;
    } else { width=MIN(width,maxWidth); height=MIN(height,maxHeight); }
    NSRect frame=NSMakeRect(sx<0 ? anchor.x-width : anchor.x,sy<0 ? anchor.y-height : anchor.y,width,height);
    return DPEaselTransformObject(object,frame);
}
@end
