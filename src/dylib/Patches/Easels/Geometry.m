#import "Geometry.h"
#import <math.h>
NSRect DPEaselDragRect(NSPoint anchor,NSPoint end,BOOL square) {
    double dx=end.x-anchor.x,dy=end.y-anchor.y;
    if(square) { double length=MAX(fabs(dx),fabs(dy)); dx=copysign(length,dx); dy=copysign(length,dy); }
    return NSMakeRect(anchor.x+MIN(0,dx),anchor.y+MIN(0,dy),fabs(dx),fabs(dy));
}
NSPoint DPEaselStraightEnd(NSPoint anchor,NSPoint end) {
    CGFloat length=hypot(end.x-anchor.x,end.y-anchor.y);
    CGFloat angle=round(atan2(end.y-anchor.y,end.x-anchor.x)/(M_PI/4))*(M_PI/4);
    return NSMakePoint(anchor.x+length*cos(angle),anchor.y+length*sin(angle));
}
NSBezierPath *DPEaselArrow(NSPoint start,NSPoint end,CGFloat lineWidth) {
    NSBezierPath *path=NSBezierPath.bezierPath;
    path.lineWidth=lineWidth; path.lineCapStyle=NSLineCapStyleRound; path.lineJoinStyle=NSLineJoinStyleRound;
    [path moveToPoint:start]; [path lineToPoint:end];
    CGFloat length=hypot(end.x-start.x,end.y-start.y);
    if(length<1) return path;
    CGFloat angle=atan2(end.y-start.y,end.x-start.x),head=MIN(length*.4,MAX(12,lineWidth*4));
    for(NSNumber *side in @[@(-1),@1]) {
        CGFloat ray=angle+side.doubleValue*M_PI/6;
        [path moveToPoint:end]; [path lineToPoint:NSMakePoint(end.x-head*cos(ray),end.y-head*sin(ray))];
    }
    return path;
}
static NSPoint DPPoint(NSArray *value) { return NSMakePoint([value[0] doubleValue],[value[1] doubleValue]); }
NSBezierPath *DPEaselSmoothPath(NSArray<NSArray<NSNumber *> *> *points) {
    NSBezierPath *path=NSBezierPath.bezierPath; path.lineCapStyle=NSLineCapStyleRound; path.lineJoinStyle=NSLineJoinStyleRound;
    if(!points.count) return path;
    [path moveToPoint:DPPoint(points[0])];
    if(points.count==1) return path;
    // Midpoint quadratics, expressed as cubics; only the live tail changes as
    // samples arrive. This avoids a global curve fit on every pointer event.
    NSPoint current=DPPoint(points[0]);
    for(NSUInteger index=1;index<points.count;index++) {
        NSPoint control=DPPoint(points[index-1]),next=DPPoint(points[index]);
        NSPoint end=index==points.count-1 ? next : NSMakePoint((control.x+next.x)/2,(control.y+next.y)/2);
        [path curveToPoint:end controlPoint1:NSMakePoint(current.x+(control.x-current.x)*2/3,current.y+(control.y-current.y)*2/3)
            controlPoint2:NSMakePoint(end.x+(control.x-end.x)*2/3,end.y+(control.y-end.y)*2/3)];
        current=end;
    }
    return path;
}
