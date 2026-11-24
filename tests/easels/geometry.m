#import "Patches/Easels/Geometry.h"
#import <stdio.h>
int main(void) { @autoreleasepool {
    for(NSNumber *x in @[@(-30),@30]) for(NSNumber *y in @[@(-60),@60]) {
        NSRect rect=DPEaselDragRect(NSMakePoint(100,100),NSMakePoint(100+x.doubleValue,100+y.doubleValue),YES);
        NSCAssert(rect.size.width==60 && rect.size.height==60,@"Shift square in every direction");
    }
    NSPoint end=DPEaselStraightEnd(NSZeroPoint,NSMakePoint(100,9));
    NSCAssert(fabs(end.y)<.001,@"Shift pen locks straight segment");
    for(NSString *type in @[@"rectangle",@"oval",@"heart",@"line",@"triangle",@"diamond",@"star",@"pentagon",@"hexagon"]) {
        NSArray *points=DPEaselTemplate(type,NSMakeRect(10,30,180,140));
        NSCAssert([DPEaselRecognize(points) isEqual:type],@"Recognizes supported complete shape: %@",type);
        NSMutableArray *noise=NSMutableArray.new;
        for(NSUInteger i=0;i<points.count;i++) {
            NSArray *p=points[i]; [noise addObject:@[@([p[0] doubleValue]+sin(i)*2),@([p[1] doubleValue]+cos(i)*2)]];
        }
        NSCAssert([DPEaselRecognize(noise) isEqual:type],@"Tolerates small hand-drawn error: %@",type);
    }
    for(NSString *type in @[@"rectangle",@"oval",@"heart",@"triangle",@"diamond",@"star"]) {
        NSArray *points=DPEaselTemplate(type,NSMakeRect(20,30,180,140));
        NSArray *loose=[points subarrayWithRange:NSMakeRange(0,points.count-5)];
        NSCAssert([DPEaselRecognize(loose) isEqual:type],@"a loose endpoint gap still recognizes %@",type);
    }
    NSDictionary *square=DPEaselRecognition(DPEaselTemplate(@"rectangle",NSMakeRect(20,30,180,170)));
    NSCAssert(fabs([square[@"rect"] rectValue].size.width-[square[@"rect"] rectValue].size.height)<.01,@"near-square strokes refine to exact equal sides");
    NSArray *arc=[DPEaselTemplate(@"oval",NSMakeRect(0,0,100,100)) subarrayWithRange:NSMakeRange(0,35)];
    NSCAssert(!DPEaselRecognize(arc),@"Open partial curve is not an oval");
    NSCAssert(!DPEaselRecognize(@[@[@0,@0]]),@"A tap is not a shape");
    NSArray *scribble=@[@[@0,@0],@[@100,@40],@[@50,@10],@[@90,@90],@[@10,@10],@[@10,@80],@[@100,@0],@[@0,@0]];
    NSCAssert(!DPEaselRecognize(scribble),@"Uncertain scribble stays freehand");
    NSCAssert(DPEaselArrow(NSZeroPoint,NSMakePoint(20,30),3).elementCount==6,@"Arrow has directed shaft and two head segments");
    NSRect raw=NSMakeRect(203,104,100,80);
    NSArray *neighbors=@[[NSValue valueWithRect:NSMakeRect(200,400,100,80)]];
    NSDictionary *snapped=DPEaselSnap(raw,neighbors,NSMakeSize(900,1400),NO);
    NSCAssert([snapped[@"rect"] rectValue].origin.x==200,@"nearby object edge snaps within four points");
    NSDictionary *first=DPEaselSnap(NSMakeRect(398,657,100,80),@[],NSMakeSize(900,1400),NO);
    NSRect centered=[first[@"rect"] rectValue];
    NSCAssert(NSMidX(centered)==450 && NSMidY(centered)==700 && [first[@"guides"] count]==2,@"first object aligns to both canvas centers without any neighbors");
    NSRect edge=[DPEaselSnap(NSMakeRect(797,1317,100,80),@[],NSMakeSize(900,1400),NO)[@"rect"] rectValue];
    NSCAssert(NSMaxX(edge)==900 && NSMaxY(edge)==1400,@"empty canvas also supplies its far edges");
    NSCAssert(NSEqualRects([DPEaselSnap(raw,neighbors,NSMakeSize(900,1400),YES)[@"rect"] rectValue],raw),@"Option bypass preserves exact pointer intent");
    NSRect distant=NSMakeRect(210,104,100,80);
    NSCAssert([DPEaselSnap(distant,neighbors,NSMakeSize(900,1400),NO)[@"rect"] rectValue].origin.x==210,@"snapping never pulls from far away");
    puts("PASS: constrained geometry, arrow, line/rectangle/oval/heart recognition, noise tolerance and conservative fallback");
} }
