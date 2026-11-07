#import "SidebarGrain.h"

@interface NSWindow (DPGrainAppearance)
- (BOOL)_hasActiveAppearance;
@end
@interface NSView (DPGrainAppearance)
- (void)_windowChangedKeyState;
@end

@implementation DPSidebarGrainView {
    CGFloat _grainOpacity, _softness;
    NSString *_material;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.wantsLayer = YES;
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    return self;
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)setFrame:(NSRect)frame {
    [super setFrame:self.superview ? DPGrainHostBounds(self.superview) : frame];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification,
         NSWindowDidBecomeMainNotification, NSWindowDidResignMainNotification,
         NSApplicationDidBecomeActiveNotification, NSApplicationDidResignActiveNotification])
        [center removeObserver:self name:name object:nil];
    if (self.window && self.tracksWindowActivity) {
        [center addObserver:self selector:@selector(refreshActivity:) name:NSWindowDidBecomeKeyNotification object:self.window];
        [center addObserver:self selector:@selector(refreshActivity:) name:NSWindowDidResignKeyNotification object:self.window];
        [center addObserver:self selector:@selector(refreshActivity:) name:NSWindowDidBecomeMainNotification object:self.window];
        [center addObserver:self selector:@selector(refreshActivity:) name:NSWindowDidResignMainNotification object:self.window];
        [center addObserver:self selector:@selector(refreshActivity:) name:NSApplicationDidBecomeActiveNotification object:NSApp];
        [center addObserver:self selector:@selector(refreshActivity:) name:NSApplicationDidResignActiveNotification object:NSApp];
        [self refreshActivity:nil];
    }
}

- (void)refreshActivity:(NSNotification *)notification {
    [self setGrainAmount:DPGrainAmount() softness:DPGrainSoftness()];
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (void)_windowChangedKeyState {
    [super _windowChangedKeyState];
    [self refreshActivity:nil];
}

- (void)setGrainAmount:(double)amount softness:(double)softness {
    NSString *material = DPChoice(&DPSidebarGrain);
    if (![DPGrainMaterialKeys() containsObject:material]) material = @"grain";
    BOOL pattern = DPIsPatternGrainMaterial(material), matte = [material isEqual:@"matte"];
    CGFloat normalized = MAX(0, MIN(100, amount)) / 100;
    CGFloat opacity = pattern ? DPPatternGrainStrength(material) * normalized :
        matte ? pow(normalized, 1.15) : (0.66 * pow(0.60, 1.35)) * pow(normalized, 1.35);
    if (self.tracksWindowActivity && self.window && !self.window._hasActiveAppearance) opacity = 0;
    CGFloat soft = MAX(0, MIN(100, softness)) / 100;
    if (_grainOpacity == opacity && _softness == soft && [_material isEqual:material]) return;
    _softness = soft;
    _grainOpacity = opacity;
    _material = material;
    // Multiply the tile into the existing material; the backing image stays static.
    self.layer.compositingFilter = [material isEqual:@"fine"] ? nil : @"multiplyBlendMode";
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_grainOpacity == 0) return;
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);
    CGFloat radius = self.layer.cornerRadius;
    if (radius > 0) {
        CGPathRef clip = CGPathCreateWithRoundedRect(self.bounds, radius, radius, NULL);
        CGContextAddPath(context, clip);
        CGPathRelease(clip);
        CGContextClip(context);
    } else {
        CGContextClipToRect(context, self.bounds);
    }
    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    if (![_material isEqual:@"fine"]) {
        BOOL pattern = DPIsPatternGrainMaterial(_material);
        CGFloat size = pattern ? 100 : 128 + 32 * _softness;
        CGFloat strength = _grainOpacity * (pattern ? 1 - .65 * _softness : 1);
        CGRect tile = CGRectMake(0, 0, size, size);
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        CGContextSetAlpha(context, strength * (1 - _softness));
        CGContextDrawTiledImage(context, tile, pattern ? DPPatternGrainTile(_material, NO) : DPMatteGrainTile(NO));
        CGContextSetBlendMode(context, kCGBlendModePlusLighter);
        CGContextSetAlpha(context, strength * _softness);
        CGContextDrawTiledImage(context, tile, pattern ? DPPatternGrainTile(_material, YES) : DPMatteGrainTile(YES));
    } else {
        CGContextSetAlpha(context, _grainOpacity * (1 - 0.45 * _softness));
        CGContextDrawTiledImage(context, CGRectMake(0, 0, 120 + 24 * _softness, 120 + 24 * _softness), DPFineGrainTile());
    }
    CGContextRestoreGState(context);
}

@end
