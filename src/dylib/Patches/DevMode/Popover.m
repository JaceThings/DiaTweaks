#import "Controls.h"

static const CGFloat DPPopoverWidth = 240, DPMargin = 10, DPPreviewAspect = 0.53;

static void DPPress(NSView *view, BOOL down) {
    CALayer *layer = view.layer;
    CGFloat scale = down ? 0.97 : 1;
    CATransform3D transform = CATransform3DMakeTranslation(NSMidX(view.bounds), NSMidY(view.bounds), 0);
    transform = CATransform3DScale(transform, scale, scale, 1);
    transform = CATransform3DTranslate(transform, -NSMidX(view.bounds), -NSMidY(view.bounds), 0);
    CABasicAnimation *press = [CABasicAnimation animationWithKeyPath:@"transform"];
    press.fromValue = [NSValue valueWithCATransform3D:(layer.presentationLayer ?: layer).transform];
    press.toValue = [NSValue valueWithCATransform3D:transform];
    press.duration = down ? 0.08 : 0.2;
    press.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    layer.transform = transform;
    [layer addAnimation:press forKey:@"press"];
}

@interface DPFirstMouseButton : NSButton
@end
@implementation DPFirstMouseButton
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {
    DPPress(self, YES);
    [super mouseDown:event];
    DPPress(self, NO);
}
@end

@interface DPPortraitControls : NSStackView
@property (nonatomic, weak) id page;
@property (nonatomic, weak) NSWindow *browserWindow;
@property (nonatomic) NSImage *shot;
@property (nonatomic) NSImageView *preview;
@property (nonatomic) DPSwatch *black, *wallpaper;
@property (nonatomic) DPHueSlider *slider;
@end

@implementation DPPortraitControls

- (BOOL)isFlipped { return YES; }

- (DPSwatch *)swatchWithAction:(SEL)action label:(NSString *)label {
    DPSwatch *swatch = [DPSwatch new];
    swatch.target = self;
    swatch.action = action;
    swatch.label = swatch.accessibilityLabel = label;
    swatch.accessibilityElement = YES;
    swatch.accessibilityRole = NSAccessibilityButtonRole;
    return swatch;
}

- (NSButton *)captureButton {
    NSButton *button = [DPFirstMouseButton buttonWithTitle:@"" target:self action:@selector(capture:)];
    button.bordered = NO;
    button.attributedTitle = [[NSAttributedString alloc] initWithString:@"Capture in Portrait Mode" attributes:@{ NSFontAttributeName : [NSFont systemFontOfSize:14 weight:NSFontWeightMedium], NSForegroundColorAttributeName : [NSColor colorWithWhite:1 alpha:0.9] }];
    button.wantsLayer = YES;
    button.layer.cornerRadius = 8;
    button.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.08].CGColor;
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [NSColor colorWithWhite:1 alpha:0.1].CGColor;
    [button.heightAnchor constraintEqualToConstant:34].active = YES;
    return button;
}

- (instancetype)initWithPage:(id)page window:(NSWindow *)window {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.page = page;
    self.browserWindow = window;
    CGFloat width = DPPopoverWidth - 2 * DPMargin;
    self.preview = [NSImageView new];
    self.preview.imageScaling = NSImageScaleAxesIndependently;
    self.preview.wantsLayer = YES;
    self.preview.layer.cornerRadius = 8;
    self.preview.layer.masksToBounds = YES;
    self.preview.layer.backgroundColor = NSColor.blackColor.CGColor;
    [self.preview.heightAnchor constraintEqualToConstant:round(width * DPPreviewAspect)].active = YES;
    self.black = [self swatchWithAction:@selector(chooseBlack:) label:@"Black"];
    self.black.color = NSColor.blackColor;
    self.wallpaper = [self swatchWithAction:@selector(chooseWallpaper:) label:@"Desktop wallpaper"];
    self.wallpaper.image = [[NSImage alloc] initWithContentsOfURL:[NSWorkspace.sharedWorkspace desktopImageURLForScreen:window.screen ?: NSScreen.mainScreen]];
    self.slider = [DPHueSlider new];
    self.slider.value = DPPortraitHueValue();
    self.slider.target = self;
    self.slider.action = @selector(chooseHue:);
    NSStackView *row = [NSStackView stackViewWithViews:@[ self.wallpaper, self.slider, self.black ]];
    row.spacing = 8;
    for (NSView *view in @[ [self captureButton], self.preview, row ]) {
        [self addArrangedSubview:view];
        [view.widthAnchor constraintEqualToConstant:width].active = YES;
    }
    self.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.spacing = 10;
    self.edgeInsets = NSEdgeInsetsMake(DPMargin, DPMargin, DPMargin, DPMargin);
    [self refresh];
    return self;
}

- (void)choose:(DPPortraitBackground)background {
    DPSetPortraitStyle(background, self.slider.value);
    [self refresh];
}

- (void)chooseWallpaper:(id)sender { [self choose:DPPortraitWallpaper]; }
- (void)chooseBlack:(id)sender { [self choose:DPPortraitBlack]; }
- (void)chooseHue:(id)sender { [self choose:DPPortraitHue]; }

- (void)refresh {
    DPPortraitBackground choice = DPPortraitChoice();
    self.slider.selected = choice == DPPortraitHue;
    self.black.selected = choice == DPPortraitBlack;
    self.wallpaper.selected = choice == DPPortraitWallpaper;
    CGFloat width = 2 * (DPPopoverWidth - 2 * DPMargin);
    if (self.shot) self.preview.image = DPPortraitImage(self.shot, self.browserWindow, width, DPPreviewAspect);
}

- (void)capture:(id)sender {
    DPCloseBubble();
    if (self.page) DPCapturePortrait(self.page);
}

@end

void DPShowPortraitPopover(NSView *button, id page) {
    if (DPBubbleShown()) return;
    DPPortraitControls *controls = [[DPPortraitControls alloc] initWithPage:page window:button.window];
    DPShowBubble(button, controls);
    DPCaptureViewport(page, ^(NSImage *shot) {
        controls.shot = shot;
        [controls refresh];
    });
}
