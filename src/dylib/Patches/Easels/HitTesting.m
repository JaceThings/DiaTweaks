#import "Canvas.h"
static CGFloat DPDistance(NSPoint p,NSPoint a,NSPoint b) {
    CGFloat dx=b.x-a.x,dy=b.y-a.y,length=dx*dx+dy*dy;
    CGFloat t=length ? MAX(0,MIN(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/length)) : 0;
    return hypot(p.x-a.x-t*dx,p.y-a.y-t*dy);
}
@implementation DPEaselCanvas (HitTesting)
- (NSDictionary *)objectAtPoint:(NSPoint)point {
    CGFloat unit=DPEaselScreenUnit(self);
    NSArray *objects=[self displayObjects];
    if(self.hitObjects!=objects) {
        self.hitObjects=objects;
        self.hitOrder=[objects sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [b[@"z"] compare:a[@"z"]]; }];
    }
    for(NSDictionary *object in self.hitOrder) {
        NSRect rect=DPEaselObjectRect(object); if(!NSPointInRect(point,NSInsetRect(rect,-6*unit,-6*unit))) continue;
        NSString *type=object[@"type"];
        if([type isEqual:@"text"] || [type isEqual:@"image"]) return object;
        if([self.selection containsObject:object[@"id"]] && [@[@"rectangle",@"oval",@"heart",@"triangle",@"diamond",@"star",@"pentagon",@"hexagon"] containsObject:type] && NSPointInRect(point,rect)) return object;
        BOOL outline=[object[@"outline"] boolValue];
        if([type isEqual:@"rectangle"]) {
            if(!outline || !NSPointInRect(point,NSInsetRect(rect,5*unit,5*unit))) return object;
            continue;
        }
        if([type isEqual:@"oval"]) {
            CGFloat x=(point.x-NSMidX(rect))/MAX(1,rect.size.width/2),y=(point.y-NSMidY(rect))/MAX(1,rect.size.height/2);
            CGFloat radius=hypot(x,y),tolerance=6*unit/MAX(1,MIN(rect.size.width,rect.size.height)/2);
            if(outline ? fabs(radius-1)<=tolerance : radius<=1+tolerance) return object;
            continue;
        }
        NSArray *points=object[@"points"];
        CGFloat tolerance=MAX(6*unit,[object[@"stroke"] doubleValue]/2+3*unit);
        for(NSUInteger i=1;i<points.count;i++) {
            NSArray *a=points[i-1],*b=points[i];
            if(DPDistance(point,NSMakePoint([a[0] doubleValue],[a[1] doubleValue]),NSMakePoint([b[0] doubleValue],[b[1] doubleValue]))<=tolerance) return object;
        }
    }
    return nil;
}
@end
