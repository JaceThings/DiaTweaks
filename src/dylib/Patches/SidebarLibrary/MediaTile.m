#import "Library.h"
@interface DPLibraryMediaView ()
@property NSTrackingArea *tracking;
@property NSView *mat;
@end
static CATransform3D DPLibraryMediaTransform(CALayer *layer,CGFloat scale) {
    CATransform3D transform = CATransform3DMakeScale(scale,scale,1);
    // AppKit anchors backing layers at (0,0). Keep the white frame's center
    // fixed while growing the frame and image together.
    transform.m41 = (1-scale)*NSWidth(layer.bounds)*(.5-layer.anchorPoint.x);
    transform.m42 = (1-scale)*NSHeight(layer.bounds)*(.5-layer.anchorPoint.y);
    return transform;
}
@implementation DPLibraryMediaView
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.mat = [NSView new]; self.mat.wantsLayer = YES;
        self.mat.layer.backgroundColor = NSColor.whiteColor.CGColor;
        self.mat.layer.cornerRadius = 0; self.mat.layer.masksToBounds = NO; self.mat.layer.shadowRadius=8; self.mat.layer.shadowOffset=CGSizeZero;
        [self addSubview:self.mat];
        NSImageView *image = [NSImageView new]; image.imageScaling = NSImageScaleProportionallyUpOrDown;
        [self.mat addSubview:image]; self.imageView = image;
    } return self;
}
// Route gestures through the item; NSImageView can otherwise start its own
// image-only drag instead of the collection's file-URL drag session.
- (NSView *)hitTest:(NSPoint)point { return [super hitTest:point] ? self : nil; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if (self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:self.tracking];
    [self dpLibraryUpdatePointerHover];
}
- (void)refreshImage {
    NSSize size = self.imageView.image.size; if (size.width <= 0 || size.height <= 0) size = NSMakeSize(64,64);
    CGFloat scale = MIN(MAX(1,NSWidth(self.bounds)-32)/size.width,MAX(1,NSHeight(self.bounds)-32)/size.height);
    size = NSMakeSize(size.width*scale+8,size.height*scale+8);
    NSRect frame = NSMakeRect((NSWidth(self.bounds)-size.width)/2,(NSHeight(self.bounds)-size.height)/2,size.width,size.height);
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (!NSEqualRects(self.mat.frame,frame)) {
        self.mat.frame = frame;
        self.mat.layer.transform = DPLibraryMediaTransform(self.mat.layer,self.hovered ? 1.025 : 1);
    }
    self.mat.layer.shadowColor=NSColor.labelColor.CGColor;
    CGPathRef shadow=CGPathCreateWithRect(self.mat.bounds,NULL); self.mat.layer.shadowPath=shadow; CGPathRelease(shadow);
    self.imageView.frame = NSInsetRect(self.mat.bounds,4,4);
    [CATransaction commit]; self.needsDisplay = YES;
}
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self refreshImage]; }
- (void)layout { [super layout]; [self refreshImage]; }
- (void)drawRect:(NSRect)dirty {
    if (!self.hovered && !self.chosen) return;
    [[NSColor.labelColor colorWithAlphaComponent:self.chosen ? .14 : .08] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,3,3) xRadius:13 yRadius:13] fill];
}
- (void)setHover:(BOOL)hover {
    if (self.hovered == hover) return;
    self.hovered = hover; self.needsDisplay = YES;
    CALayer *layer = self.mat.layer;
    CATransform3D current = layer.presentationLayer ? layer.presentationLayer.transform : layer.transform;
    CATransform3D target = DPLibraryMediaTransform(layer,hover ? 1.025 : 1);
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    layer.shadowOpacity=hover ? .16 : 0;
    layer.transform = target; [CATransaction commit];
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) { [layer removeAnimationForKey:@"mediaHover"]; return; }
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation.fromValue = [NSValue valueWithCATransform3D:current]; animation.toValue = [NSValue valueWithCATransform3D:target]; animation.duration = hover ? .20 : .24;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:animation forKey:@"mediaHover"];
    CABasicAnimation *glow=[CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    glow.fromValue=@(hover ? 0 : .16); glow.toValue=@(hover ? .16 : 0); glow.duration=animation.duration; glow.timingFunction=animation.timingFunction;
    [layer addAnimation:glow forKey:@"mediaGlow"];
}
- (NSRect)framedRect { return self.mat.frame; }
- (NSImage *)framedImage {
    NSRect rect=self.mat.bounds; NSBitmapImageRep *rep=[self.mat bitmapImageRepForCachingDisplayInRect:rect];
    if (!rep) return nil;
    [self.mat cacheDisplayInRect:rect toBitmapImageRep:rep];
    NSImage *image=[[NSImage alloc] initWithSize:rect.size]; [image addRepresentation:rep]; return image;
}
- (void)resetHover {
    self.hovered = NO; [self.mat.layer removeAnimationForKey:@"mediaHover"]; [self.mat.layer removeAnimationForKey:@"mediaGlow"];
    [CATransaction begin]; [CATransaction setDisableActions:YES]; self.mat.layer.shadowOpacity=0; self.mat.layer.transform = CATransform3DIdentity; [CATransaction commit];
    self.needsDisplay=YES;
}
- (void)dpLibraryUpdatePointerHover { [self setHover:DPLibraryPointerInside(self)]; }
- (void)mouseEntered:(NSEvent *)event { if(self.window) [self dpLibraryUpdatePointerHover]; else [self setHover:YES]; }
- (void)mouseExited:(NSEvent *)event { if(self.window) [self dpLibraryUpdatePointerHover]; else [self setHover:NO]; }
@end
