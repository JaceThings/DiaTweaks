#import "Canvas.h"
NSDictionary *DPEaselTransformObject(NSDictionary *object,NSRect frame) {
    NSRect old=DPEaselObjectRect(object);
    NSMutableDictionary *result=[object mutableCopy]; result[@"rect"]=DPEaselRectArray(frame);
    if(object[@"points"]) {
        NSMutableArray *points=NSMutableArray.new;
        for(NSArray *point in object[@"points"]) [points addObject:@[
            @(frame.origin.x+([point[0] doubleValue]-old.origin.x)*frame.size.width/MAX(1,old.size.width)),
            @(frame.origin.y+([point[1] doubleValue]-old.origin.y)*frame.size.height/MAX(1,old.size.height))]];
        result[@"points"]=points;
    }
    return result;
}
