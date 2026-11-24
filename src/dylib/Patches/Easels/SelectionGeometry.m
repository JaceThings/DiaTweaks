#import "Canvas.h"
CGFloat DPEaselScreenUnit(NSView *view) {
    CGFloat scale=fabs([view convertSize:NSMakeSize(1,1) toView:nil].width);
    return scale>.0001 ? 1/scale : 1;
}
NSArray<NSValue *> *DPEaselSelectionHandles(NSDictionary *object) {
    if([object[@"type"] isEqual:@"arrow"] && [object[@"points"] count]>=2) {
        NSArray *a=[object[@"points"] firstObject],*b=[object[@"points"] lastObject];
        return @[[NSValue valueWithPoint:NSMakePoint([a[0] doubleValue],[a[1] doubleValue])],
                 [NSValue valueWithPoint:NSMakePoint([b[0] doubleValue],[b[1] doubleValue])]];
    }
    NSRect r=DPEaselObjectRect(object);
    return @[[NSValue valueWithPoint:r.origin],[NSValue valueWithPoint:NSMakePoint(NSMaxX(r),NSMinY(r))],
        [NSValue valueWithPoint:NSMakePoint(NSMaxX(r),NSMaxY(r))],[NSValue valueWithPoint:NSMakePoint(NSMinX(r),NSMaxY(r))]];
}
NSArray<NSValue *> *DPEaselVisualHandles(NSDictionary *object,CGFloat unit) {
    if([object[@"type"] isEqual:@"arrow"]) return DPEaselSelectionHandles(object);
    NSMutableDictionary *expanded=[object mutableCopy];
    expanded[@"rect"]=DPEaselRectArray(NSInsetRect(DPEaselObjectRect(object),-4*unit,-4*unit));
    return DPEaselSelectionHandles(expanded);
}
