#import "Library.h"
void DPLibraryMoveSectionHighlight(DPLibraryController *owner,BOOL animated) {
    NSButton *selected=nil;
    for(NSView *v in owner.rail.subviews) if([v.identifier isEqual:@"category"] && [(NSButton *)v state]) selected=(id)v;
    NSView *box=owner.sectionHighlight; if(!selected || !box) return;
    [box.effectiveAppearance performAsCurrentDrawingAppearance:^{ box.layer.backgroundColor=[NSColor.labelColor colorWithAlphaComponent:.10].CGColor; }];
    BOOL changed=!NSEqualRects(box.frame,selected.frame);
    [box.layer removeAnimationForKey:@"sectionSlide"];
    [CATransaction begin]; [CATransaction setDisableActions:YES]; box.frame=selected.frame; [CATransaction commit];
    if(!changed || !animated || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return;
    CABasicAnimation *press=[CABasicAnimation animationWithKeyPath:@"opacity"];
    press.fromValue=@.7; press.toValue=@1; press.duration=.12;
    press.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [box.layer addAnimation:press forKey:@"sectionPress"];
}
