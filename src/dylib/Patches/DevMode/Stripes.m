#import "DevMode.h"

static const CGFloat DPStripeGap = 9, DPStripeWidth = 3.5;
static char DPStripesKey, DPDiaAppearanceKey, DPDiaFillKey;
static BOOL DPSettingOurs;

// Dia picks the toolbar's appearance to suit the site's color. While striped it takes the profile's, and gets Dia's back after.
static void DPBar_setAppearance(NSView *self, SEL _cmd, NSAppearance *appearance) {
    if (!DPSettingOurs) {
        DPSet(self, &DPDiaAppearanceKey, appearance ?: NSNull.null);
        if ([DPGet(self, &DPStripesKey) alphaValue] > 0) return;
    }
    DPCallOriginal(DPBar_setAppearance, self, appearance);
}

static void DPSetBarAppearance(NSView *bar, NSAppearance *appearance) {
    if (!DPGet(bar, &DPDiaAppearanceKey)) DPSet(bar, &DPDiaAppearanceKey, bar.appearance ?: NSNull.null);
    DPSettingOurs = YES;
    bar.appearance = appearance;
    DPSettingOurs = NO;
}

static void DPRestoreBarAppearance(NSView *bar) {
    id dia = DPGet(bar, &DPDiaAppearanceKey);
    if (!dia) return;
    DPSettingOurs = YES;
    bar.appearance = dia == NSNull.null ? nil : dia;
    DPSettingOurs = NO;
}

// Dia fills the address field with the site's color. While striped it keeps the plain fill Dia gives white and black sites.
static void DPSetFill(CALayer *fill, CGColorRef color) {
    DPSettingOurs = YES;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    fill.backgroundColor = color;
    [CATransaction commit];
    DPSettingOurs = NO;
}

static void DPHoldFill(CALayer *fill, NSAppearance *appearance) {
    if (!fill) return;
    if (!DPGet(fill, &DPDiaFillKey)) DPSet(fill, &DPDiaFillKey, (__bridge id)fill.backgroundColor ?: NSNull.null);
    __block NSColor *plain;
    [appearance performAsCurrentDrawingAppearance:^{ plain = [NSColor colorWithCGColor:[NSColor.labelColor colorWithAlphaComponent:0.1].CGColor]; }];
    if (!CGColorEqualToColor(fill.backgroundColor, plain.CGColor)) DPSetFill(fill, plain.CGColor);
}

static void DPReleaseFill(CALayer *fill) {
    id dia = fill ? DPGet(fill, &DPDiaFillKey) : nil;
    if (!dia) return;
    DPSetFill(fill, dia == NSNull.null ? NULL : (__bridge CGColorRef)dia);
    DPSet(fill, &DPDiaFillKey, nil);
}

// The window's own tint: a wash and a gradient of the profile's color, over its material.
static NSView *DPWindowTint(NSWindow *window) {
    NSView *found = nil;
    for (NSView *tint in DPFindViews(DPDiaWindowTint))
        if (tint.window == window && NSWidth(tint.frame) * NSHeight(tint.frame) > NSWidth(found.frame) * NSHeight(found.frame)) found = tint;
    return found;
}

@interface DPStripesView : NSView
@property(nonatomic) NSVisualEffectView *material;
@property(nonatomic) CALayer *wash;
@property(nonatomic) CAGradientLayer *profile;
@property(nonatomic) CAShapeLayer *stripes;
@property(nonatomic, weak) CAGradientLayer *watched;
@property(nonatomic, weak) CALayer *fill;
@property(nonatomic) BOOL plain;
@end

@implementation DPStripesView
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.material = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
    self.material.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.material.state = NSVisualEffectStateFollowsWindowActiveState;
    NSView *paint = [[NSView alloc] initWithFrame:self.bounds];
    paint.layer = [CALayer layer];
    paint.layer.masksToBounds = YES;
    paint.wantsLayer = YES;
    paint.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    for (CALayer *layer in @[ self.wash = [CALayer layer], self.profile = [CAGradientLayer layer], self.stripes = [CAShapeLayer layer] ]) [paint.layer addSublayer:layer];
    self.stripes.lineWidth = DPStripeWidth;
    self.stripes.fillColor = nil;
    [self addSubview:self.material];
    [self addSubview:paint];
    return self;
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

// Switching profiles changes the window's gradient without laying out the toolbar.
- (void)watch:(CAGradientLayer *)gradient {
    if (gradient == self.watched) return;
    [self.watched removeObserver:self forKeyPath:@"colors"];
    [gradient addObserver:self forKeyPath:@"colors" options:0 context:NULL];
    self.watched = gradient;
}

- (void)observeValueForKeyPath:(NSString *)path ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.fill) {
        if (DPSettingOurs) return;
        DPSet(object, &DPDiaFillKey, nil);
    }
    if (NSThread.isMainThread) [self followTheme];
    else dispatch_async(dispatch_get_main_queue(), ^{ [self followTheme]; });
}

- (CALayer *)watchFill {
    NSView *field = DPFindView(self.superview, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAddressField); });
    CALayer *fill = field.subviews.firstObject.layer;
    if (fill != self.fill) {
        [self.fill removeObserver:self forKeyPath:@"backgroundColor"];
        [fill addObserver:self forKeyPath:@"backgroundColor" options:0 context:NULL];
        self.fill = fill;
    }
    return fill;
}

- (void)dealloc {
    [self.watched removeObserver:self forKeyPath:@"colors"];
    [self.fill removeObserver:self forKeyPath:@"backgroundColor"];
}

- (void)followTheme {
    NSView *tint = DPWindowTint(self.window);
    NSVisualEffectView *effect = (NSVisualEffectView *)DPFindView(tint.superview, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSVisualEffectView.class] && !view.isHiddenOrHasHiddenAncestor;
    });
    CAGradientLayer *gradient = nil;
    NSView *wash = nil;
    for (NSView *view in tint.subviews) {
        if (DPIsKind(view, DPDiaColorView)) wash = view;
        for (CALayer *layer in view.layer.sublayers) if ([layer isKindOfClass:CAGradientLayer.class]) gradient = (CAGradientLayer *)layer;
    }
    [self watch:gradient];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    // The toolbar takes the profile's appearance too, so its buttons and address stay readable.
    if (!self.plain && self.alphaValue > 0 && tint) {
        DPSetBarAppearance(self.superview, tint.effectiveAppearance);
        DPHoldFill([self watchFill], tint.effectiveAppearance);
    }
    self.stripes.hidden = self.plain;
    if (effect) {
        self.material.material = effect.material;
        self.material.blendingMode = effect.blendingMode;
    }
    self.wash.frame = self.bounds;
    self.wash.backgroundColor = wash.hidden ? nil : wash.layer.backgroundColor;
    self.profile.colors = gradient.colors;
    self.profile.startPoint = gradient.startPoint;
    self.profile.endPoint = gradient.endPoint;
    self.profile.frame = tint ? [self convertRect:tint.bounds fromView:tint] : self.bounds;
    CGFloat height = NSHeight(self.bounds);
    CGMutablePathRef path = CGPathCreateMutable();
    for (CGFloat x = -height; x < NSWidth(self.bounds) + height; x += DPStripeGap) {
        CGPathMoveToPoint(path, NULL, x, 0);
        CGPathAddLineToPoint(path, NULL, x + height, height);
    }
    self.stripes.path = path;
    CGPathRelease(path);
    BOOL dark = [tint.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
    self.stripes.strokeColor = [NSColor colorWithWhite:dark alpha:0.06].CGColor;
    [CATransaction commit];
}

- (void)layout {
    [super layout];
    [self followTheme];
}

- (void)viewDidChangeEffectiveAppearance { [self followTheme]; }
@end

NSAppearance *DPProfileAppearance(NSWindow *window) { return DPWindowTint(window).effectiveAppearance; }

NSView *DPMakeProfileBackground(void) {
    DPStripesView *view = [DPStripesView new];
    view.plain = YES;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    return view;
}

void DPShowStripes(NSView *bar, BOOL shown) {
    DPStripesView *stripes = DPGet(bar, &DPStripesKey);
    if (!stripes && !shown) return;
    if (!stripes) {
        DPSet(bar, &DPStripesKey, stripes = [[DPStripesView alloc] initWithFrame:bar.bounds]);
        stripes.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        stripes.alphaValue = 0;
    }
    if (stripes.superview != bar) [bar addSubview:stripes positioned:NSWindowAbove relativeTo:bar.subviews.firstObject];
    if ((stripes.alphaValue > 0.5) == shown) {
        if (shown) [stripes followTheme];
        return;
    }
    if (shown) {
        stripes.alphaValue = 0.01;
        [stripes followTheme];
    } else {
        DPRestoreBarAppearance(bar);
        DPReleaseFill(stripes.fill);
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.25;
        stripes.animator.alphaValue = shown;
    } completionHandler:^{
        if (stripes.alphaValue == 0) DPRestoreBarAppearance(bar);
    }];
}

BOOL DPStripesShown(NSView *bar) { return [DPGet(bar, &DPStripesKey) alphaValue] > 0.5; }

void DPInstallStripes(void) { DPHook(DPDiaToolbar, @selector(setAppearance:), (IMP)DPBar_setAppearance); }
