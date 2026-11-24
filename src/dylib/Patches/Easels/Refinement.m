#import "Canvas.h"
#import "Patches/SidebarLibrary/MotionClock.h"
static NSArray *DPSamplePath(NSArray *points,NSUInteger count) {
    if(points.count<2) return points;
    NSMutableArray *lengths=[NSMutableArray arrayWithObject:@0]; CGFloat total=0;
    for(NSUInteger i=1;i<points.count;i++) {
        total+=hypot([points[i][0] doubleValue]-[points[i-1][0] doubleValue],[points[i][1] doubleValue]-[points[i-1][1] doubleValue]); [lengths addObject:@(total)];
    }
    NSMutableArray *result=NSMutableArray.new; NSUInteger segment=1;
    for(NSUInteger i=0;i<count;i++) {
        CGFloat distance=total*i/(count-1);
        while(segment<points.count-1 && [lengths[segment] doubleValue]<distance) segment++;
        CGFloat base=[lengths[segment-1] doubleValue],span=[lengths[segment] doubleValue]-base;
        CGFloat t=span ? (distance-base)/span : 0;
        [result addObject:@[@([points[segment-1][0] doubleValue]+t*([points[segment][0] doubleValue]-[points[segment-1][0] doubleValue])),
                           @([points[segment-1][1] doubleValue]+t*([points[segment][1] doubleValue]-[points[segment-1][1] doubleValue]))]];
    }
    return result;
}
@implementation DPEaselCanvas (Refinement)
- (void)animateRefinementFrom:(NSArray *)points {
    [self.refinementClock stop]; self.refinementClock=nil;
    NSDictionary *target=[self.draft copy]; NSArray *from=DPSamplePath(points,64),*to=DPSamplePath(target[@"points"],64);
    if(from.count!=to.count || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion || !self.window) {
        self.previewObjects=[self.initialObjects arrayByAddingObject:target]; self.needsDisplay=YES; return;
    }
    // Closed strokes may start at any edge and run in either direction. Match
    // the nearest phase so refinement doesn't rotate or flip before settling.
    if(![target[@"type"] isEqual:@"line"]) {
        double best=INFINITY; NSArray *aligned=to;
        for(NSUInteger shift=0;shift<to.count;shift++) for(NSNumber *direction in @[@1,@(-1)]) {
            NSMutableArray *candidate=NSMutableArray.new; double error=0;
            for(NSUInteger i=0;i<to.count;i++) {
                NSInteger index=((NSInteger)shift+direction.integerValue*(NSInteger)i+(NSInteger)to.count)%(NSInteger)to.count;
                NSArray *point=to[index]; [candidate addObject:point];
                error+=pow([from[i][0] doubleValue]-[point[0] doubleValue],2)+pow([from[i][1] doubleValue]-[point[1] doubleValue],2);
            }
            if(error<best) { best=error; aligned=candidate; }
        }
        to=aligned;
    }
    CFTimeInterval start=CACurrentMediaTime(); __weak DPEaselCanvas *weak=self;
    self.refinementClock=DPLibraryMotionClock.new;
    self.refinementClock.frame=^{
        DPEaselCanvas *canvas=weak; if(!canvas || !canvas.draft) return;
        CGFloat progress=MIN(1,(CACurrentMediaTime()-start)/.2),t=progress*progress*(3-2*progress);
        NSMutableArray *interpolated=NSMutableArray.new;
        for(NSUInteger i=0;i<from.count;i++) [interpolated addObject:@[@([from[i][0] doubleValue]+t*([to[i][0] doubleValue]-[from[i][0] doubleValue])),
            @([from[i][1] doubleValue]+t*([to[i][1] doubleValue]-[from[i][1] doubleValue]))]];
        NSMutableDictionary *preview=[target mutableCopy]; preview[@"type"]=@"pen"; preview[@"points"]=interpolated;
        canvas.previewObjects=[canvas.initialObjects arrayByAddingObject:progress<1 ? preview : target];
        [canvas setNeedsDisplayInRect:NSInsetRect(DPEaselObjectRect(target),-10,-10)];
        if(progress>=1) { [canvas.refinementClock stop]; canvas.refinementClock=nil; }
    };
    [self.refinementClock startForWindow:self.window];
}
@end
