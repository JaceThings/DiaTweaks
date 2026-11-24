#import "Geometry.h"
#import <math.h>
NSArray<NSArray<NSNumber *> *> *DPEaselTemplate(NSString *type,NSRect bounds) {
    NSMutableArray *points=NSMutableArray.new;
    NSDictionary *sides=@{@"triangle":@3,@"diamond":@4,@"pentagon":@5,@"hexagon":@6,@"star":@10};
    NSUInteger vertices=[sides[type] unsignedIntegerValue];
    for(NSUInteger index=0;index<=96;index++) {
        double t=index/96.0,x=0,y=0;
        if(vertices) {
            double side=t*vertices; NSUInteger a=(NSUInteger)floor(side)%vertices,b=(a+1)%vertices; double fraction=side-floor(side);
            double ra=[type isEqual:@"star"] && a%2 ? .22 : .5,rb=[type isEqual:@"star"] && b%2 ? .22 : .5;
            double aa=a*2*M_PI/vertices-M_PI_2,ab=b*2*M_PI/vertices-M_PI_2;
            x=.5+ra*cos(aa)*(1-fraction)+rb*cos(ab)*fraction; y=.5+ra*sin(aa)*(1-fraction)+rb*sin(ab)*fraction;
        }
        else if([type isEqual:@"oval"]) { x=.5+.5*cos(t*2*M_PI); y=.5+.5*sin(t*2*M_PI); }
        else if([type isEqual:@"rectangle"]) {
            double side=t*4;
            if(side<1) { x=side; y=0; }
            else if(side<2) { x=1; y=side-1; }
            else if(side<3) { x=3-side; y=1; }
            else { x=0; y=4-side; }
        } else if([type isEqual:@"heart"]) {
            double angle=t*2*M_PI;
            x=16*pow(sin(angle),3); y=-(13*cos(angle)-5*cos(2*angle)-2*cos(3*angle)-cos(4*angle));
        } else if([type isEqual:@"line"]) { x=t; y=t; }
        else return @[];
        [points addObject:@[@(x),@(y)]];
    }
    double minX=INFINITY,minY=INFINITY,maxX=-INFINITY,maxY=-INFINITY;
    for(NSArray *point in points) {
        minX=MIN(minX,[point[0] doubleValue]); maxX=MAX(maxX,[point[0] doubleValue]);
        minY=MIN(minY,[point[1] doubleValue]); maxY=MAX(maxY,[point[1] doubleValue]);
    }
    for(NSUInteger i=0;i<points.count;i++) {
        NSArray *point=points[i];
        double x=([point[0] doubleValue]-minX)/MAX(.001,maxX-minX);
        double y=([point[1] doubleValue]-minY)/MAX(.001,maxY-minY);
        points[i]=@[@(bounds.origin.x+x*bounds.size.width),@(bounds.origin.y+y*bounds.size.height)];
    }
    return points;
}
