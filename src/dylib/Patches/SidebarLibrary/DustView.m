#import "Dust.h"
static CGFloat DPSmoothDust(CGFloat lower,CGFloat upper,CGFloat value) {
    CGFloat t=MIN(1,MAX(0,(value-lower)/(upper-lower))); return t*t*(3-2*t);
}
@implementation DPLibraryDust
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (void)start {
    self.started=CACurrentMediaTime(); self.clock=DPLibraryMotionClock.new;
    __weak DPLibraryDust *weak=self;
    self.clock.frame=^{ weak.needsDisplay=YES; }; [self.clock startForWindow:self.window];
}
- (void)stop { [self.clock stop]; self.clock=nil; }
- (void)dealloc { [_clock stop]; }
- (void)drawRect:(NSRect)dirty {
    CGFloat t=MIN(1,MAX(0,(CACurrentMediaTime()-self.started)/.62));
    CGFloat lift=DPSmoothDust(0,.24,t);
    if(lift<.999) [self.image drawInRect:self.imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1-lift respectFlipped:YES hints:nil];
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    const DPLibraryParticle *points=self.samples.bytes; NSUInteger count=self.samples.length/sizeof(*points);
    for(NSUInteger i=0;i<count;i++) {
        DPLibraryParticle p=points[i];
        CGFloat delay=.08*p.seed,phase=MIN(1,MAX(0,(t-delay)/(1-delay)));
        CGFloat fade=1-DPSmoothDust(.36,1,phase); if(fade<.001) continue;
        CGFloat move=phase*phase;
        CGFloat x=self.imageRect.origin.x+p.x+(18+34*p.seed)*move+sin(p.seed*18+phase*5)*3*phase;
        CGFloat y=self.imageRect.origin.y+p.y-(32+36*p.seed)*move;
        CGFloat size=self.step*(1-.62*DPSmoothDust(.12,1,phase));
        CGContextSetRGBFillColor(context,p.r,p.g,p.b,p.a*lift*fade*.72);
        CGContextFillRect(context,CGRectMake(x-size/2,y-size/2,size,size));
    }
}
@end
