#import "Dust.h"
static NSMutableSet *DPLibraryDissolves;
@interface DPLibraryDissolveState : NSObject
@property NSMutableArray<DPLibraryDust *> *overlays;
@property NSMutableArray *hidden;
@property DPLibraryMotionClock *clock;
@property(copy) void (^completion)(void);
@property BOOL finished;
- (void)finish;
@end
@implementation DPLibraryDissolveState
- (void)finish {
    if(self.finished) return; self.finished=YES;
    [self.clock stop]; self.clock=nil;
    self.completion(); self.completion=nil;
    for(NSArray *entry in self.hidden) [(NSView *)entry[0] setAlphaValue:[entry[1] doubleValue]];
    for(DPLibraryDust *dust in self.overlays) [dust removeFromSuperview];
    [self.hidden removeAllObjects]; [self.overlays removeAllObjects]; [DPLibraryDissolves removeObject:self];
}
@end
void DPLibraryStopDissolves(void) { for(DPLibraryDissolveState *state in DPLibraryDissolves.copy) [state finish]; }
void DPLibraryDissolve(NSArray<NSView *> *views,void (^completion)(void)) {
    if(!DPSidebarLibraryDust.on || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion || !views.count) { completion(); return; }
    DPLibraryDissolveState *state=DPLibraryDissolveState.new; state.overlays=NSMutableArray.new; state.hidden=NSMutableArray.new; state.completion=completion;
    NSUInteger budget=8000/MAX(1,views.count); CFTimeInterval began=CACurrentMediaTime();
    for(NSView *view in views) {
        NSRect visible=NSIntersectionRect(view.bounds,view.visibleRect); NSView *root=view.window.contentView;
        if(!root || NSIsEmptyRect(visible)) continue;
        NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:visible]; if(!rep) continue;
        [view cacheDisplayInRect:visible toBitmapImageRep:rep];
        NSImage *image=[[NSImage alloc] initWithSize:visible.size]; [image addRepresentation:rep];
        CGImageRef cg=[image CGImageForProposedRect:NULL context:nil hints:nil]; if(!cg) continue;
        NSRect frame=[root convertRect:visible fromView:view]; if(root.isFlipped) frame.origin.y-=96;
        frame.size.width+=80; frame.size.height+=96;
        DPLibraryDust *dust=[[DPLibraryDust alloc] initWithFrame:frame]; dust.image=image;
        dust.imageRect=NSMakeRect(0,96,NSWidth(visible),NSHeight(visible));
        CGFloat spacing=0; dust.samples=DPLibraryDustSamples(cg,visible.size,budget,&spacing); dust.step=spacing;
        dust.started=began; [root addSubview:dust positioned:NSWindowAbove relativeTo:nil];
        [state.overlays addObject:dust]; [state.hidden addObject:@[view,@(view.alphaValue)]]; view.alphaValue=0;
    }
    if(!state.overlays.count) { completion(); return; }
    if(!DPLibraryDissolves) DPLibraryDissolves=NSMutableSet.new; [DPLibraryDissolves addObject:state];
    state.clock=DPLibraryMotionClock.new; __weak DPLibraryDissolveState *weak=state;
    state.clock.frame=^{ for(DPLibraryDust *dust in weak.overlays) dust.needsDisplay=YES; };
    [state.clock startForWindow:state.overlays.firstObject.window];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,640*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ [state finish]; });
}
