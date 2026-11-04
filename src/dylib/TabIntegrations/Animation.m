#import "Native.h"

void DPTabIntegrationFade(NSView *view, float opacity, void (^completion)(void)) {
    view.wantsLayer = YES;
    CALayer *layer = view.layer;
    CALayer *presentation = layer.presentationLayer;
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @((presentation ?: layer).opacity);
    fade.toValue = @(opacity);
    fade.duration = 0.1;
    fade.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.25 :0.46 :0.45 :0.94];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [CATransaction setCompletionBlock:completion];
    layer.opacity = opacity;
    [layer addAnimation:fade forKey:@"DPTabIntegrationFade"];
    [CATransaction commit];
}
