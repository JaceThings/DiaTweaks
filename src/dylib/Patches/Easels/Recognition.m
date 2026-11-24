#import "Geometry.h"
#import <math.h>
static double DPDistance(NSArray *a,NSArray *b) { return hypot([a[0] doubleValue]-[b[0] doubleValue],[a[1] doubleValue]-[b[1] doubleValue]); }
static double DPCloudError(NSArray *a,NSArray *b) {
    double total=0,worst=0;
    for(NSArray *point in a) {
        double distance=INFINITY; for(NSArray *candidate in b) distance=MIN(distance,DPDistance(point,candidate));
        total+=distance; worst=MAX(worst,distance);
    }
    return total/MAX(1,a.count)*.7+worst*.3;
}
static NSArray *DPNormalize(NSArray *points,double angle) {
    NSMutableArray *rotated=NSMutableArray.new; double minX=INFINITY,minY=INFINITY,maxX=-INFINITY,maxY=-INFINITY;
    for(NSArray *p in points) {
        double x=[p[0] doubleValue]-.5,y=[p[1] doubleValue]-.5;
        double rx=x*cos(angle)-y*sin(angle),ry=x*sin(angle)+y*cos(angle);
        [rotated addObject:@[@(rx),@(ry)]]; minX=MIN(minX,rx); minY=MIN(minY,ry); maxX=MAX(maxX,rx); maxY=MAX(maxY,ry);
    }
    NSMutableArray *result=NSMutableArray.new;
    for(NSArray *p in rotated) [result addObject:@[@(([p[0] doubleValue]-minX)/MAX(.001,maxX-minX)),@(([p[1] doubleValue]-minY)/MAX(.001,maxY-minY))]];
    return result;
}
NSDictionary *DPEaselRecognition(NSArray<NSArray<NSNumber *> *> *points) {
    if(points.count<8) return nil;
    double minX=INFINITY,minY=INFINITY,maxX=-INFINITY,maxY=-INFINITY,length=0;
    for(NSUInteger i=0;i<points.count;i++) {
        NSArray *p=points[i]; if(p.count!=2 || !isfinite([p[0] doubleValue]) || !isfinite([p[1] doubleValue])) return nil;
        minX=MIN(minX,[p[0] doubleValue]); maxX=MAX(maxX,[p[0] doubleValue]); minY=MIN(minY,[p[1] doubleValue]); maxY=MAX(maxY,[p[1] doubleValue]);
        if(i) length+=DPDistance(points[i-1],p);
    }
    NSRect bounds=NSMakeRect(minX,minY,maxX-minX,maxY-minY);
    double diagonal=hypot(bounds.size.width,bounds.size.height),endDistance=DPDistance(points.firstObject,points.lastObject);
    if(diagonal<24 || length<24) return nil;
    if(endDistance>diagonal*.8 && length<endDistance*2) {
        NSArray *start=points.firstObject,*end=points.lastObject;
        double dx=[end[0] doubleValue]-[start[0] doubleValue],dy=[end[1] doubleValue]-[start[1] doubleValue],deviation=0;
        for(NSArray *p in points) deviation=MAX(deviation,fabs(([p[0] doubleValue]-[start[0] doubleValue])*dy-([p[1] doubleValue]-[start[1] doubleValue])*dx)/endDistance);
        if(deviation<MAX(3,diagonal*.025)) return @{@"type":@"line",@"points":@[start,end],@"rect":[NSValue valueWithRect:bounds]};
    }
    if(endDistance>diagonal*.4 || bounds.size.width<16 || bounds.size.height<16) return nil;
    NSMutableArray *normalized=NSMutableArray.new; NSUInteger step=MAX(1,(points.count+127)/128);
    for(NSUInteger i=0;i<points.count;i+=step) [normalized addObject:@[@(([points[i][0] doubleValue]-minX)/bounds.size.width),@(([points[i][1] doubleValue]-minY)/bounds.size.height)]];
    NSString *best=nil; NSArray *bestPoints=nil; double score=.095;
    for(NSString *type in @[@"rectangle",@"oval",@"heart",@"triangle",@"diamond",@"star",@"pentagon",@"hexagon"]) {
        NSUInteger rotations=[@[@"triangle",@"heart",@"pentagon",@"hexagon",@"star"] containsObject:type] ? 4 : 1;
        NSArray *base=DPEaselTemplate(type,NSMakeRect(0,0,1,1));
        for(NSUInteger rotation=0;rotation<rotations;rotation++) {
            NSArray *ideal=DPNormalize(base,rotation*M_PI_2);
            double error=MAX(DPCloudError(normalized,ideal),DPCloudError(ideal,normalized));
            if(error<score) { score=error; best=type; bestPoints=ideal; }
        }
    }
    if(!best) return nil;
    if([@[@"rectangle",@"oval"] containsObject:best] && MAX(bounds.size.width,bounds.size.height)/MIN(bounds.size.width,bounds.size.height)<1.12) {
        CGFloat side=MIN(bounds.size.width,bounds.size.height); bounds=NSMakeRect(NSMidX(bounds)-side/2,NSMidY(bounds)-side/2,side,side);
    }
    NSMutableArray *refined=NSMutableArray.new;
    for(NSArray *p in bestPoints) [refined addObject:@[@(bounds.origin.x+[p[0] doubleValue]*bounds.size.width),@(bounds.origin.y+[p[1] doubleValue]*bounds.size.height)]];
    return @{@"type":best,@"points":refined,@"rect":[NSValue valueWithRect:bounds]};
}
NSString *DPEaselRecognize(NSArray *points) { return DPEaselRecognition(points)[@"type"]; }
