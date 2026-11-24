#import "Canvas.h"
NSUInteger DPEaselCropEdges(NSRect rect,NSPoint point,CGFloat tolerance) {
    if(!NSPointInRect(point,NSInsetRect(rect,-tolerance,-tolerance))) return 0;
    NSUInteger edges=0;
    if(fabs(point.x-NSMinX(rect))<tolerance) edges|=1; else if(fabs(point.x-NSMaxX(rect))<tolerance) edges|=2;
    if(fabs(point.y-NSMinY(rect))<tolerance) edges|=4; else if(fabs(point.y-NSMaxY(rect))<tolerance) edges|=8;
    return edges;
}
NSCursor *DPEaselCropCursor(NSUInteger edges) {
    if(@available(macOS 15.0,*)) {
        NSCursorFrameResizePosition position=0;
        if(edges&1) position|=NSCursorFrameResizePositionLeft; if(edges&2) position|=NSCursorFrameResizePositionRight;
        if(edges&4) position|=NSCursorFrameResizePositionTop; if(edges&8) position|=NSCursorFrameResizePositionBottom;
        return [NSCursor frameResizeCursorFromPosition:position inDirections:NSCursorFrameResizeDirectionsAll];
    }
    return edges&3 ? NSCursor.resizeLeftRightCursor : NSCursor.resizeUpDownCursor;
}
NSDictionary *DPEaselCropImage(NSDictionary *object,NSPoint point,NSUInteger edges,NSPoint offset,NSRect canvas) {
    NSArray *crop=object[@"crop"] ?: @[@0,@0,@1,@1]; NSRect rect=DPEaselObjectRect(object);
    CGFloat fullWidth=rect.size.width/[crop[2] doubleValue],fullHeight=rect.size.height/[crop[3] doubleValue];
    NSRect full=NSMakeRect(rect.origin.x-[crop[0] doubleValue]*fullWidth,rect.origin.y-[crop[1] doubleValue]*fullHeight,fullWidth,fullHeight);
    CGFloat left=NSMinX(rect),right=NSMaxX(rect),top=NSMinY(rect),bottom=NSMaxY(rect);
    point.x-=offset.x; point.y-=offset.y;
    if(edges&1) left=MAX(MAX(NSMinX(full),NSMinX(canvas)),MIN(right-4,point.x));
    if(edges&2) right=MIN(MIN(NSMaxX(full),NSMaxX(canvas)),MAX(left+4,point.x));
    if(edges&4) top=MAX(MAX(NSMinY(full),NSMinY(canvas)),MIN(bottom-4,point.y));
    if(edges&8) bottom=MIN(MIN(NSMaxY(full),NSMaxY(canvas)),MAX(top+4,point.y));
    NSMutableDictionary *result=[object mutableCopy]; result[@"rect"]=DPEaselRectArray(NSMakeRect(left,top,right-left,bottom-top));
    result[@"crop"]=@[@((left-NSMinX(full))/fullWidth),@((top-NSMinY(full))/fullHeight),@((right-left)/fullWidth),@((bottom-top)/fullHeight)]; return result;
}
NSRect DPEaselImageSourceRect(NSDictionary *object,NSImage *image) {
    NSArray *crop=object[@"crop"]; if(crop.count!=4) return NSZeroRect;
    return NSMakeRect([crop[0] doubleValue]*image.size.width,(1-[crop[1] doubleValue]-[crop[3] doubleValue])*image.size.height,[crop[2] doubleValue]*image.size.width,[crop[3] doubleValue]*image.size.height);
}
@implementation DPEaselCanvas (ImageCrop)
- (void)resetImageCrop:(id)sender {
    NSMutableArray *objects=[self.document.objects mutableCopy];
    for(NSUInteger i=0;i<objects.count;i++) if([self.selection containsObject:objects[i][@"id"]] && [objects[i][@"type"] isEqual:@"image"]) {
        NSMutableDictionary *object=[objects[i] mutableCopy]; [object removeObjectForKey:@"crop"]; objects[i]=object;
    }
    [self commit:objects action:@"Reset Image Crop"];
}
@end
