#import "Canvas.h"
static NSCursor *DPResizeCursor(NSDictionary *object,NSInteger handle) {
    if(@available(macOS 15.0,*)) {
        NSCursorFrameResizePosition positions[]={NSCursorFrameResizePositionTopLeft,NSCursorFrameResizePositionTopRight,NSCursorFrameResizePositionBottomRight,NSCursorFrameResizePositionBottomLeft};
        if([object[@"type"] isEqual:@"arrow"]) {
            NSArray *points=object[@"points"]; if(points.count>=2) {
                NSArray *a=points[0],*b=points[1]; CGFloat dx=[b[0] doubleValue]-[a[0] doubleValue],dy=[b[1] doubleValue]-[a[1] doubleValue];
                if(fabs(dx)>fabs(dy)*2) return NSCursor.columnResizeCursor;
                if(fabs(dy)>fabs(dx)*2) return NSCursor.rowResizeCursor;
                handle=dx*dy>=0 ? 0 : 1;
            }
        }
        return [NSCursor frameResizeCursorFromPosition:positions[MAX(0,MIN(3,handle))] inDirections:NSCursorFrameResizeDirectionsAll];
    }
    return NSCursor.crosshairCursor;
}
@implementation DPEaselCanvas (InteractionCursors)
- (NSCursor *)interactionCursorAtPoint:(NSPoint)point {
    if(![self.tool isEqual:@"select"]) return [self drawingCursor];
    NSDictionary *selected=nil;
    if(self.selection.count==1) for(NSDictionary *object in [self displayObjects]) if([self.selection containsObject:object[@"id"]]) { selected=object; break; }
    if(self.cropping) return DPEaselCropCursor(self.cropEdges);
    if(selected && [selected[@"type"] isEqual:@"image"] && (self.pointerModifiers&NSEventModifierFlagCommand)) {
        NSUInteger edges=DPEaselCropEdges(DPEaselObjectRect(selected),point,9*DPEaselScreenUnit(self));
        if(edges) return DPEaselCropCursor(edges);
    }
    if(self.resizing>=0) return DPResizeCursor(selected,self.resizing);
    if(self.moving && self.draggingSelection) return self.duplicatingSelection ? NSCursor.dragCopyCursor : NSCursor.closedHandCursor;
    if(selected) {
        NSArray *handles=DPEaselVisualHandles(selected,DPEaselScreenUnit(self));
        for(NSUInteger i=0;i<handles.count;i++) { NSPoint handle=[handles[i] pointValue];
            if(hypot(point.x-handle.x,point.y-handle.y)<9*DPEaselScreenUnit(self)) return DPResizeCursor(selected,i);
        }
    }
    return [self drawingCursor];
}
- (NSCursor *)interactionCursorForEvent:(NSEvent *)event {
    self.pointerModifiers=event.modifierFlags;
    if(DPEaselCursorOverChrome(self,event.locationInWindow)) return NSCursor.arrowCursor;
    return [self interactionCursorAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
}
- (void)flagsChanged:(NSEvent *)event { [[self interactionCursorForEvent:event] set]; }
@end
