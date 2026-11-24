#import "Canvas.h"
@implementation DPEaselCanvas (PointerDown)
- (void)mouseDown:(NSEvent *)event {
    [DPEaselHost finishEditingDocument:self.document]; [self endText]; [self.window makeFirstResponder:self]; [self cancelGesture];
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil]; self.origin=point;
    if([self.tool isEqual:@"image"]) { [self placeImage:self.pendingAsset size:self.pendingSize atPoint:point]; return; }
    self.initialObjects=self.document.objects;
    if([self.tool isEqual:@"select"]) {
        NSDictionary *hit=[self objectAtPoint:point];
        if(self.selection.count==1) for(NSDictionary *object in self.document.objects) if([self.selection containsObject:object[@"id"]]) {
            NSRect r=DPEaselObjectRect(object);
            if((event.modifierFlags&NSEventModifierFlagCommand) && [object[@"type"] isEqual:@"image"]) {
                NSUInteger edges=DPEaselCropEdges(r,point,9*DPEaselScreenUnit(self));
                if(edges) {
                    self.cropping=YES; self.cropEdges=edges; NSPoint raw=point;
                    if(edges&1) raw.x=NSMinX(r); if(edges&2) raw.x=NSMaxX(r); if(edges&4) raw.y=NSMinY(r); if(edges&8) raw.y=NSMaxY(r);
                    self.resizeGrabOffset=NSMakePoint(point.x-raw.x,point.y-raw.y); [[self interactionCursorForEvent:event] set]; return;
                }
            }
            CGFloat unit=DPEaselScreenUnit(self); NSArray *corners=DPEaselVisualHandles(object,unit);
            BOOL edge=NSPointInRect(point,NSInsetRect(r,-7*unit,-7*unit)) && !NSPointInRect(point,NSInsetRect(r,7*unit,7*unit));
            if(event.clickCount==2 && edge && [object[@"type"] isEqual:@"text"]) { [self fitText:object]; return; }
            for(NSUInteger i=0;i<corners.count;i++) { NSPoint p=[corners[i] pointValue]; if(hypot(p.x-point.x,p.y-point.y)<9*unit) {
                self.resizing=i; NSPoint raw=[DPEaselSelectionHandles(object)[i] pointValue];
                self.resizeGrabOffset=NSMakePoint(point.x-raw.x,point.y-raw.y); [[self interactionCursorAtPoint:point] set]; return;
            } }
        }
        if(hit) {
            NSString *identifier=hit[@"id"];
            if(event.modifierFlags&NSEventModifierFlagShift) {
                if([self.selection containsObject:identifier]) [self.selection removeObject:identifier]; else [self.selection addObject:identifier];
            } else if(![self.selection containsObject:identifier]) [self.selection setSet:[NSSet setWithObject:identifier]];
            if(event.clickCount==2 && [hit[@"type"] isEqual:@"text"]) { [self beginText:hit]; return; }
            self.moving=self.selection.count>0;
        } else { if(!(event.modifierFlags&NSEventModifierFlagShift)) [self.selection removeAllObjects]; self.marquee=YES; self.selectionBox=NSMakeRect(point.x,point.y,0,0); }
    } else {
        NSUInteger order=0; for(NSDictionary *object in self.document.objects) order=MAX(order,[object[@"order"] unsignedIntegerValue]+1);
        self.draft=[@{@"id":NSUUID.UUID.UUIDString,@"type":self.tool,@"order":@(order),@"z":@(order),@"color":self.color ?: @[@0,@0,@0,@1],@"semanticInk":@(self.color==nil),
            @"rect":DPEaselRectArray(NSMakeRect(point.x,point.y,1,1)),@"stroke":@3} mutableCopy];
        if(self.colorAppearance.length) self.draft[@"colorAppearance"]=self.colorAppearance;
        if([@[@"oval",@"rectangle"] containsObject:self.tool]) self.draft[@"outline"]=@(DPEaselShapeOutline(self.tool));
        if([self.tool isEqual:@"text"]) { self.draft[@"text"]=@""; self.draft[@"font"]=self.textStyle[@"font"] ?: @"sans"; self.draft[@"size"]=self.textStyle[@"size"] ?: @24; }
        if([self.tool isEqual:@"pen"] || [self.tool isEqual:@"arrow"]) self.samples=[NSMutableArray arrayWithObject:@[@(point.x),@(point.y)]];
    }
    [[self interactionCursorAtPoint:point] set]; self.needsDisplay=YES; if(self.selectionChanged) self.selectionChanged();
}
@end
