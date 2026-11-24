#import "ToolButton.h"
#import "Canvas.h"
@implementation DPEaselToolButton
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.arrowCursor]; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (NSString *)accessibilityRole { return NSAccessibilityRadioButtonRole; }
- (id)accessibilityValue { return @(self.state==NSControlStateValueOn); }
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if(self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking=[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect owner:self userInfo:nil]; [self addTrackingArea:self.tracking];
}
- (void)mouseEntered:(NSEvent *)event { self.pointerInside=YES; self.needsDisplay=YES; }
- (void)mouseExited:(NSEvent *)event { self.pointerInside=NO; self.needsDisplay=YES; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; self.pointerInside=NO; self.needsDisplay=YES; }
- (void)drawRect:(NSRect)dirty {
    if(self.pointerInside && (!self.window.keyWindow || !NSPointInRect([self convertPoint:self.window.mouseLocationOutsideOfEventStream fromView:nil],self.bounds))) self.pointerInside=NO;
    if(self.state || self.pointerInside) {
        [[(self.state ? DPEaselAccent(self) : NSColor.labelColor) colorWithAlphaComponent:self.state ? .16 : .07] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8] fill];
    }
    [super drawRect:dirty];
    if(self.pointerInside && NSWidth(self.bounds)>=30) [self.letter drawAtPoint:NSMakePoint(NSWidth(self.bounds)-8,self.isFlipped ? NSHeight(self.bounds)-11 : 1) withAttributes:@{
        NSFontAttributeName:[NSFont systemFontOfSize:8 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:DPEaselAccent(self)}];
}
@end
