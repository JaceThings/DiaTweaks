#import "Library.h"
@interface DPLibraryRefreshButton : DPLibraryButton
@property CALayer *glyph;
@end
@implementation DPLibraryRefreshButton
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.wantsLayer = YES; self.glyph = [CALayer layer];
        self.glyph.name = @"LibraryRefreshGlyph";
        self.glyph.anchorPoint = CGPointMake(.5,.5); self.glyph.bounds = CGRectMake(0,0,16,16);
        self.glyph.contentsGravity = kCAGravityResizeAspect; [self.layer addSublayer:self.glyph];
    } return self;
}
- (void)updateGlyph {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        NSImage *image = [[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[NSColor.labelColor]]];
        self.glyph.contents = (__bridge id)[image CGImageForProposedRect:NULL context:nil hints:nil];
    }];
    self.glyph.contentsScale = self.window.backingScaleFactor ?: 2;
}
- (void)layout {
    [super layout]; [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.glyph.position = CGPointMake(NSMidX(self.bounds),NSMidY(self.bounds)); [CATransaction commit];
}
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self updateGlyph]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateGlyph]; }
@end
NSButton *DPLibraryMakeRefreshButton(id target,SEL action) {
    NSButton *button = [DPLibraryRefreshButton buttonWithTitle:@"" target:target action:action];
    button.bordered = NO; return button;
}
void DPLibraryAnimateRefresh(NSButton *button) {
    CALayer *glyph = [(DPLibraryRefreshButton *)button glyph];
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) { [glyph removeAnimationForKey:@"libraryRefresh"]; return; }
    CATransform3D shown = glyph.presentationLayer ? glyph.presentationLayer.transform : CATransform3DIdentity;
    CGFloat start = atan2(shown.m12,shown.m11);
    CAKeyframeAnimation *tilt = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    tilt.values = @[@(start),@(M_PI/12),@0]; tilt.keyTimes = @[@0,@.35,@1]; tilt.duration = .28;
    tilt.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                             [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [glyph addAnimation:tilt forKey:@"libraryRefresh"];
}
