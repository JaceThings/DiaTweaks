#import "Geometry.h"
NSDictionary *DPEaselSnap(NSRect proposed,NSArray<NSValue *> *neighbors,NSSize canvas,BOOL bypass) {
    return DPEaselSnapWithin(proposed,neighbors,canvas,bypass,4);
}
NSDictionary *DPEaselSnapWithin(NSRect proposed,NSArray<NSValue *> *neighbors,NSSize canvas,BOOL bypass,CGFloat radius) {
    if(bypass) return @{@"rect":[NSValue valueWithRect:proposed],@"guides":@[]};
    NSMutableArray *xs=[@[@0,@(canvas.width/2),@(canvas.width)] mutableCopy];
    NSMutableArray *ys=[@[@0,@(canvas.height/2),@(canvas.height)] mutableCopy];
    for(NSValue *value in neighbors) {
        NSRect rect=value.rectValue;
        [xs addObjectsFromArray:@[@(NSMinX(rect)),@(NSMidX(rect)),@(NSMaxX(rect))]];
        [ys addObjectsFromArray:@[@(NSMinY(rect)),@(NSMidY(rect)),@(NSMaxY(rect))]];
    }
    NSMutableArray *guides=NSMutableArray.new;
    NSArray *anchors=@[@[@(NSMinX(proposed)),@(NSMidX(proposed)),@(NSMaxX(proposed))],
        @[@(NSMinY(proposed)),@(NSMidY(proposed)),@(NSMaxY(proposed))]];
    for(NSUInteger axis=0;axis<2;axis++) {
        CGFloat best=radius+.001,target=0,delta=0; BOOL found=NO;
        for(NSNumber *anchor in anchors[axis]) for(NSNumber *candidate in (axis ? ys : xs)) {
            CGFloat difference=candidate.doubleValue-anchor.doubleValue;
            if(fabs(difference)<best) { best=fabs(difference); delta=difference; target=candidate.doubleValue; found=YES; }
        }
        if(!found) continue;
        if(axis) proposed.origin.y+=delta; else proposed.origin.x+=delta;
        [guides addObject:@{@"axis":@(axis),@"position":@(target)}];
    }
    return @{@"rect":[NSValue valueWithRect:proposed],@"guides":guides};
}
