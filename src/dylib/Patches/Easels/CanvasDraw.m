#import "Canvas.h"
@implementation DPEaselCanvas (Drawing)
- (void)drawObjects:(NSArray *)objects inRect:(NSRect)dirty selection:(BOOL)selection {
    NSArray *sorted=[objects sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [a[@"z"] compare:b[@"z"]]; }];
    for(NSDictionary *object in sorted) {
        NSRect frame=DPEaselObjectRect(object); if(!NSIntersectsRect(NSInsetRect(frame,-12,-12),dirty)) continue;
        NSString *type=object[@"type"];
        if([type isEqual:@"text"]) {
            if(![object[@"id"] isEqual:self.textObjectID]) {
            NSMutableParagraphStyle *paragraph=NSMutableParagraphStyle.new;
            paragraph.alignment=[object[@"isTitle"] boolValue] ? NSTextAlignmentCenter : NSTextAlignmentLeft;
            [object[@"text"] drawWithRect:NSInsetRect(frame,4,4) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading
                attributes:@{NSFontAttributeName:DPEaselFont(object),NSForegroundColorAttributeName:DPEaselObjectColor(object),NSParagraphStyleAttributeName:paragraph}];
            }
        } else if([type isEqual:@"image"]) {
            NSImage *image=[self.images objectForKey:object[@"asset"]];
            // The shared cache can complete synchronously during this draw.
            // Read the populated local cache again before painting a placeholder;
            // AppKit may clear needsDisplay at the end of the current draw.
            if(!image) { [self requestImage:object]; image=[self.images objectForKey:object[@"asset"]]; }
            if(image) {
                [NSGraphicsContext saveGraphicsState]; [[NSBezierPath bezierPathWithRoundedRect:frame xRadius:2 yRadius:2] addClip];
                [image drawInRect:frame fromRect:DPEaselImageSourceRect(object,image) operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil]; [NSGraphicsContext restoreGraphicsState];
            }
            else {
                [[NSColor.labelColor colorWithAlphaComponent:.05] setFill]; NSRectFillUsingOperation(frame,NSCompositingOperationSourceOver);
                if([self.failedImages containsObject:object[@"asset"]]) [@"Image unavailable" drawInRect:NSInsetRect(frame,12,12)
                    withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];
            }
        } else {
            NSBezierPath *path=nil;
            if([type isEqual:@"rectangle"]) path=[NSBezierPath bezierPathWithRoundedRect:frame xRadius:2 yRadius:2];
            else if([type isEqual:@"oval"]) path=[NSBezierPath bezierPathWithOvalInRect:frame];
            else if([type isEqual:@"heart"]) path=DPEaselSmoothPath(object[@"points"] ?: DPEaselTemplate(type,frame));
            else if([@[@"triangle",@"diamond",@"star",@"pentagon",@"hexagon"] containsObject:type]) {
                path=NSBezierPath.bezierPath; BOOL first=YES;
                for(NSArray *p in object[@"points"]) { NSPoint point=NSMakePoint([p[0] doubleValue],[p[1] doubleValue]); if(first) [path moveToPoint:point]; else [path lineToPoint:point]; first=NO; } [path closePath];
            }
            else if([type isEqual:@"arrow"] && [object[@"points"] count]>=2) {
                NSArray *a=object[@"points"][0],*b=[object[@"points"] lastObject];
                path=DPEaselArrow(NSMakePoint([a[0] doubleValue],[a[1] doubleValue]),NSMakePoint([b[0] doubleValue],[b[1] doubleValue]),[object[@"stroke"] doubleValue] ?: 3);
            } else path=DPEaselSmoothPath(object[@"points"] ?: @[]);
            [DPEaselObjectColor(object) set]; path.lineWidth=[object[@"stroke"] doubleValue] ?: 3;
            if(([type isEqual:@"oval"] || [type isEqual:@"rectangle"] || [type isEqual:@"heart"]) && ![object[@"outline"] boolValue]) [path fill];
            else [path stroke];
        }
        if(selection && ([self.selection containsObject:object[@"id"]] || ([type isEqual:@"text"] && [object[@"id"] isEqual:self.draft[@"id"]]))) {
            CGFloat unit=DPEaselScreenUnit(self);
            [DPEaselAccent(self) setStroke];
            if(![type isEqual:@"arrow"]) { NSBezierPath *border=[NSBezierPath bezierPathWithRect:NSInsetRect(frame,-4*unit,-4*unit)]; border.lineWidth=unit; [border stroke]; }
            for(NSValue *value in DPEaselVisualHandles(object,unit)) {
                NSPoint p=value.pointValue; NSBezierPath *handle=[NSBezierPath bezierPathWithRect:NSMakeRect(p.x-3.5*unit,p.y-3.5*unit,7*unit,7*unit)];
                handle.lineWidth=unit;
                [DPEaselAccent(self) setFill]; [handle fill]; [NSColor.textBackgroundColor setStroke]; [handle stroke];
            }
        }
    }
}
- (void)drawRect:(NSRect)dirty {
    [self animateVisibleImages];
    [NSColor.textBackgroundColor setFill]; NSRectFill(dirty);
    [self drawObjects:[self displayObjects] inRect:dirty selection:YES];
    [DPEaselAccent(self) setStroke];
    for(NSDictionary *guide in self.guides) {
        CGFloat position=[guide[@"position"] doubleValue]; NSBezierPath *line=NSBezierPath.bezierPath;
        line.lineWidth=DPEaselScreenUnit(self)/MAX(1,self.window.backingScaleFactor);
        [line moveToPoint:[guide[@"axis"] boolValue] ? NSMakePoint(0,position) : NSMakePoint(position,0)];
        [line lineToPoint:[guide[@"axis"] boolValue] ? NSMakePoint(NSWidth(self.bounds),position) : NSMakePoint(position,NSHeight(self.bounds))]; [line stroke];
    }
    if(self.marquee) {
        [[DPEaselAccent(self) colorWithAlphaComponent:.045] setFill]; NSRectFillUsingOperation(self.selectionBox,NSCompositingOperationSourceOver);
        [DPEaselAccent(self) setStroke]; NSBezierPath *outline=[NSBezierPath bezierPathWithRect:self.selectionBox]; outline.lineWidth=DPEaselScreenUnit(self); [outline stroke];
    }
    if(self.pendingAsset) {
        NSImage *image=[self.images objectForKey:self.pendingAsset];
        if(!image) { [self requestImage:@{@"asset":self.pendingAsset}]; image=[self.images objectForKey:self.pendingAsset]; }
        CGFloat scale=MIN(1,MIN(120/MAX(1,self.pendingSize.width),120/MAX(1,self.pendingSize.height)));
        [image drawInRect:NSMakeRect(self.pendingPoint.x+12,self.pendingPoint.y+12,self.pendingSize.width*scale,self.pendingSize.height*scale)
            fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:.7 respectFlipped:YES hints:nil];
    }
}
@end
