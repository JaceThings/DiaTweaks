#import "Patches/Peek/Peek.h"
#import "Patches/HideToolbar/HideToolbar.h"

// Dia's loading glow along the bottom of the Peek's toolbar, as its own bars and Little Dia's show it: Dia's shader in
// Dia's colors, rising from the bottom edge as far as the page has loaded, then fading once it has.
static const NSTimeInterval DPGlowFade = 0.3, DPGlowCycle = 2;

@interface DPPeekGlow : NSView
@property (nonatomic, weak) id page;
@property (nonatomic, strong) CAMetalLayer *shader;
@property (nonatomic, strong) CALayer *line;  // Without the shader: a plain line in the accent color.
@property (nonatomic, strong) NSTimer *frames;
@property (nonatomic) CGFloat fraction, shown;
@property (nonatomic) BOOL loading;
@end

@implementation DPPeekGlow
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (BOOL)wantsUpdateLayer { return YES; }

- (instancetype)initWithPage:(id)page {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.page = page;
    self.wantsLayer = YES;
    self.alphaValue = 0;
    self.shader = DPProgressShaderLayer();
    if (self.shader) {
        CAGradientLayer *fade = [CAGradientLayer layer];  // Hide Toolbar's fade, the right way up.
        fade.colors = @[(id)NSColor.blackColor.CGColor, (id)NSColor.clearColor.CGColor];
        fade.startPoint = CGPointMake(0.5, 0.35);
        fade.endPoint = CGPointMake(0.5, 1);
        self.shader.mask = fade;
        [self.layer addSublayer:self.shader];
    } else {
        self.line = [CALayer layer];
        [self.layer addSublayer:self.line];
    }
    return self;
}

- (void)dealloc { [_frames invalidate]; }

- (void)updateLayer { self.line.backgroundColor = NSColor.controlAccentColor.CGColor; }

- (void)layout {
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.shader.frame = self.bounds;
    self.shader.mask.frame = self.shader.bounds;
    self.shader.contentsScale = self.window.backingScaleFactor ?: 2;
    self.shader.drawableSize = CGSizeMake(NSWidth(self.bounds) * self.shader.contentsScale, NSHeight(self.bounds) * self.shader.contentsScale);
    self.line.frame = NSMakeRect(0, 0, round(NSWidth(self.bounds) * self.shown), 2);
    [CATransaction commit];
    [self draw];
}

- (NSView *)pane {
    for (NSView *view = self.superview; view; view = view.superview)
        if ([view isKindOfClass:DPPeekCard.class]) return ((DPPeekCard *)view).pane;
    return nil;
}

- (void)draw {
    if (!self.shader) return (void)(self.needsLayout = YES);
    simd_float3 primary, secondary;
    DPProgressColors(self.pane, @"dia", &primary, &secondary);
    DPDrawProgressShader(self.shader, self.shown, fmod(CACurrentMediaTime(), DPGlowCycle) / DPGlowCycle, primary, secondary);
}

- (void)step {
    NSObject *page = self.page;
    BOOL loading = [[page valueForKey:@"isLoading"] boolValue];
    if (loading && !self.loading) {  // Starts again from the left, as Dia's does.
        self.shown = self.fraction = 0;
        self.alphaValue = 1;
    }
    if (!loading && self.loading) {
        self.fraction = 1;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = DPGlowFade;
            self.animator.alphaValue = 0;
        }];
    }
    self.loading = loading;
    if (loading) self.fraction = MAX(self.fraction, MAX(0.1, [[page valueForKey:@"loadProgress"] doubleValue]));
    self.shown += (self.fraction - self.shown) * 0.15;
    if (self.alphaValue > 0 || loading) [self draw];
    else self.fraction = self.shown = 0;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self.frames invalidate];
    self.frames = nil;
    if (!self.window) return;
    __weak DPPeekGlow *weak = self;
    self.frames = [NSTimer timerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *timer) { [weak step]; }];
    [NSRunLoop.mainRunLoop addTimer:self.frames forMode:NSRunLoopCommonModes];
}
@end

NSView *DPPeekGlowFor(id page) { return [[DPPeekGlow alloc] initWithPage:page]; }
