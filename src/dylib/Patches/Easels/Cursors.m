#import "Canvas.h"
@implementation DPEaselCanvas (Cursors)
- (NSCursor *)drawingCursor {
    NSColor *currentAccent=DPEaselAccent(self);
    if(self.toolCursor && [currentAccent isEqual:self.cursorAccent] && [self.tool isEqual:self.cursorTool]) return self.toolCursor;
    self.cursorAccent=currentAccent; self.cursorTool=self.tool;
    NSDictionary *symbols=@{@"image":@"photo",@"text":@"textformat",@"oval":@"circle",@"rectangle":@"square",@"arrow":@"arrow.up.right",@"pen":@"pencil.tip"};
    NSString *symbol=[self.tool isEqual:@"select"] ? @"cursorarrow" : symbols[self.tool]; if(!symbol) return NSCursor.arrowCursor;
    NSColor *accent=DPEaselAccent(self);
    BOOL dark=[[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua];
    NSImage *badge=[[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[accent]]];
    BOOL selecting=[self.tool isEqual:@"select"];
    NSColor *edge=dark ? NSColor.blackColor : NSColor.whiteColor;
    NSImage *halo=[[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[edge]]];
    NSImage *image=[NSImage imageWithSize:NSMakeSize(30,30) flipped:YES drawingHandler:^BOOL(NSRect rect){
        NSRect badgeRect=selecting ? NSMakeRect(2,1,20,24) : NSMakeRect(13,12,15,15);
        if(selecting) {
            for(NSInteger x=-1;x<=1;x++) for(NSInteger y=-1;y<=1;y++) if(x || y)
                [halo drawInRect:NSOffsetRect(badgeRect,x,y) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
            [badge drawInRect:badgeRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil]; return YES;
        }
        NSBezierPath *cross=NSBezierPath.bezierPath;
        [cross moveToPoint:NSMakePoint(6,1)]; [cross lineToPoint:NSMakePoint(6,11)];
        [cross moveToPoint:NSMakePoint(1,6)]; [cross lineToPoint:NSMakePoint(11,6)];
        cross.lineWidth=1.3; [accent setStroke]; [cross stroke];
        [badge drawInRect:NSMakeRect(13,12,15,15) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        return YES;
    }];
    self.toolCursor=[[NSCursor alloc] initWithImage:image hotSpot:[self.tool isEqual:@"select"] ? NSMakePoint(4,3) : NSMakePoint(6,6)]; return self.toolCursor;
}
- (void)resetCursorRects { for(NSValue *region in DPEaselCursorRegions(self)) [self addCursorRect:region.rectValue cursor:[self drawingCursor]]; }
- (void)cursorUpdate:(NSEvent *)event { [[self interactionCursorForEvent:event] set]; }
- (void)mouseEntered:(NSEvent *)event { [[self interactionCursorForEvent:event] set]; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if(self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking=[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingCursorUpdate|NSTrackingMouseMoved|NSTrackingMouseEnteredAndExited|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:self.tracking];
}
- (void)mouseMoved:(NSEvent *)event {
    [[self interactionCursorForEvent:event] set];
    if(!self.pendingAsset) return;
    self.pendingPoint=[self convertPoint:event.locationInWindow fromView:nil]; self.needsDisplay=YES;
}
- (void)mouseExited:(NSEvent *)event { if(self.pendingAsset) { self.pendingPoint=NSMakePoint(-1000,-1000); self.needsDisplay=YES; } }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; self.toolCursor=nil; [self.window invalidateCursorRectsForView:self]; self.needsDisplay=YES; }
@end
