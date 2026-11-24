#import "Canvas.h"
#import "Patches/SidebarLibrary/MotionClock.h"
@implementation DPEaselCanvas (PointerDrag)
- (void)mouseDragged:(NSEvent *)event {
    self.recognitionToken=nil;
    if(self.moving && !self.duplicatingSelection && (event.modifierFlags&NSEventModifierFlagOption)) [self beginDuplicateDrag];
    if(self.moving) self.draggingSelection=YES;
    [[self interactionCursorForEvent:event] set];
    [self.refinementClock stop]; self.refinementClock=nil;
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
    point.x=MAX(0,MIN(NSWidth(self.bounds),point.x)); point.y=MAX(0,MIN(NSHeight(self.bounds),point.y));
    if(self.marquee) self.selectionBox=DPEaselDragRect(self.origin,point,NO);
    else if(self.moving || self.resizing>=0 || self.cropping) [self updateSelectionDrag:point modifiers:event.modifierFlags];
    else if(self.draft) {
        NSString *type=self.tool; NSRect rect=DPEaselDragRect(self.origin,point,(event.modifierFlags&NSEventModifierFlagShift) && ([type isEqual:@"oval"] || [type isEqual:@"rectangle"]));
        self.draft[@"type"]=type;
        if([type isEqual:@"arrow"] || [type isEqual:@"pen"]) {
            if(event.modifierFlags&NSEventModifierFlagShift) {
                point=DPEaselStraightEnd(self.origin,point); self.samples=[NSMutableArray arrayWithObjects:@[@(self.origin.x),@(self.origin.y)],@[@(point.x),@(point.y)],nil];
            } else if([type isEqual:@"arrow"]) self.samples=[NSMutableArray arrayWithObjects:@[@(self.origin.x),@(self.origin.y)],@[@(point.x),@(point.y)],nil];
            else {
                NSArray *last=self.samples.lastObject;
                if(hypot(point.x-[last[0] doubleValue],point.y-[last[1] doubleValue])>=1.5 && self.samples.count<100000) [self.samples addObject:@[@(point.x),@(point.y)]];
            }
            CGFloat minX=INFINITY,minY=INFINITY,maxX=-INFINITY,maxY=-INFINITY;
            for(NSArray *sample in self.samples) { minX=MIN(minX,[sample[0] doubleValue]); minY=MIN(minY,[sample[1] doubleValue]); maxX=MAX(maxX,[sample[0] doubleValue]); maxY=MAX(maxY,[sample[1] doubleValue]); }
            rect=NSMakeRect(minX,minY,MAX(1,maxX-minX),MAX(1,maxY-minY)); self.draft[@"points"]=[self.samples copy];
            if([type isEqual:@"pen"]) [self updatePenDwell];
        }
        rect.size.width=MAX(1,rect.size.width); rect.size.height=MAX(1,rect.size.height);
        self.draft[@"rect"]=DPEaselRectArray(rect); self.previewObjects=[self.initialObjects arrayByAddingObject:[self.draft copy]];
    }
    self.needsDisplay=YES;
}
- (void)mouseUp:(NSEvent *)event {
    [self.dwell invalidate]; self.dwell=nil;
    if(self.marquee) {
        for(NSDictionary *object in self.document.objects) if(NSIntersectsRect(self.selectionBox,DPEaselObjectRect(object))) [self.selection addObject:object[@"id"]];
    }
    else if(self.draft) {
        NSRect frame=DPEaselObjectRect(self.draft); BOOL text=[self.tool isEqual:@"text"];
        BOOL area=[@[@"rectangle",@"oval",@"heart"] containsObject:self.draft[@"type"]];
        if(text || area) {
            BOOL clicked=frame.size.width<4 && frame.size.height<4;
            if(clicked) {
                CGFloat width=text ? 240 : 120;
                CGFloat height=text ? 44 : ([self.tool isEqual:@"rectangle"] && !(event.modifierFlags&NSEventModifierFlagShift) ? 90 : 120);
                frame=NSMakeRect(self.origin.x,self.origin.y,width,height);
            }
            if(text) { frame.size.width=MAX(40,frame.size.width); frame.size.height=MAX(ceil(DPEaselFont(self.draft).ascender-DPEaselFont(self.draft).descender)+12,frame.size.height); }
            frame.size.width=MIN(NSWidth(self.bounds),frame.size.width); frame.size.height=MIN(NSHeight(self.bounds),frame.size.height);
            frame.origin.x=MAX(0,MIN(frame.origin.x,NSWidth(self.bounds)-frame.size.width)); frame.origin.y=MAX(0,MIN(frame.origin.y,NSHeight(self.bounds)-frame.size.height));
            self.draft[@"rect"]=DPEaselRectArray(frame);
        }
        BOOL sized=area ? frame.size.width>=4 && frame.size.height>=4 : frame.size.width>=4 || frame.size.height>=4;
        if(text || sized) {
            NSDictionary *object=[self.draft copy]; [self.selection setSet:[NSSet setWithObject:object[@"id"]]];
            [self commit:[self.initialObjects arrayByAddingObject:object] action:@"Add Object"];
            [self.window invalidateCursorRectsForView:self];
            if(text) [self beginText:object];
        }
    } else if(self.previewObjects) [self commit:self.previewObjects action:self.cropping ? @"Crop Image" : self.duplicatingSelection ? @"Duplicate and Move" : self.resizing>=0 ? @"Resize" : @"Move"];
    [self cancelGesture]; [[self interactionCursorForEvent:event] set]; if(self.selectionChanged) self.selectionChanged();
}
- (void)updatePenDwell {
    [self.dwell invalidate]; if(self.samples.count<8) return;
    __weak DPEaselCanvas *weak=self;
    self.dwell=[NSTimer timerWithTimeInterval:1.2 repeats:NO block:^(NSTimer *timer){
        [weak refineHeldStroke];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.dwell forMode:NSRunLoopCommonModes];
}
@end
