#import "LiquidGlass.h"

// Decorative only: existing controls keep their frames, responder chains and mouse handling.
@implementation DPLiquidSurface {
    NSVisualEffectView *_frost;
    NSView *_glass;
}
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.identifier = @"DiaTweaksLiquidGlass";
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 14;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
    [self setAccessibilityElement:NO];
    [self setAccessibilityHidden:YES];
    _frost = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
    [_frost setAccessibilityHidden:YES];
    _frost.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _frost.material = NSVisualEffectMaterialSidebar;
    _frost.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _frost.state = NSVisualEffectStateActive;  // Keep the backdrop visible while another app has focus.
    [self addSubview:_frost];
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:self.bounds];
        glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        glass.style = NSGlassEffectViewStyleRegular;
        glass.cornerRadius = 14;
        glass.contentView = [[NSView alloc] initWithFrame:glass.bounds];
        [glass setAccessibilityHidden:YES];
        _glass = glass;
        [self addSubview:glass];
    }
    [self refresh];
    return self;
}
- (void)layout {
    [super layout];
    NSRect frame = self.bounds;
    if (!NSEqualRects(_glass.frame, frame)) _glass.frame = frame;
    if (!NSEqualRects(_frost.frame, self.bounds)) _frost.frame = self.bounds;
}
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (BOOL)isOpaque { return NO; }
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self refresh];
}
- (void)refresh {
    BOOL solid = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency;
    _frost.hidden = solid;
    _glass.hidden = solid;
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.layer.backgroundColor = solid ? NSColor.windowBackgroundColor.CGColor : NSColor.clearColor.CGColor;
        self.layer.borderWidth = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast ? 1 : 0;
        self.layer.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.65].CGColor;
    }];
    if (@available(macOS 26.0, *)) {
        // Preserve the host's profile colour when it exposes one; otherwise use neutral native glass.
        NSColor *tint = self.superview.layer.backgroundColor ? [NSColor colorWithCGColor:self.superview.layer.backgroundColor] : nil;
        ((NSGlassEffectView *)_glass).tintColor = tint.alphaComponent > 0 ? [tint colorWithAlphaComponent:0.1] : nil;
    }
}
@end
