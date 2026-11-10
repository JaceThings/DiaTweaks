#import "DevMode.h"

static const CGFloat DPToastHeight = 36, DPToastBlur = 6, DPToastInset = 6, DPToastPadding = 14, DPToastRadius = 11;
static const NSTimeInterval DPToastFade = 0.2, DPToastHold = 4;
static char DPToastKey;

static NSURL *DPSaveURL(NSString *title) {
    NSURL *downloads = [NSFileManager.defaultManager URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask].firstObject;
    NSString *name = [[title componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/:"]] componentsJoinedByString:@"-"];
    NSURL *url = [downloads URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"jpeg"]];
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) return url;
    NSDateFormatter *format = [NSDateFormatter new];
    format.dateFormat = @"h.mma · MM-dd";
    format.AMSymbol = @"am";
    format.PMSymbol = @"pm";
    name = [NSString stringWithFormat:@"%@ · %@", name, [format stringFromDate:NSDate.date]];
    url = [downloads URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"jpeg"]];
    for (int copy = 2; [NSFileManager.defaultManager fileExistsAtPath:url.path]; copy++)
        url = [downloads URLByAppendingPathComponent:[[NSString stringWithFormat:@"%@ %d", name, copy] stringByAppendingPathExtension:@"jpeg"]];
    return url;
}

@interface DPCaptureToast : NSView
@property (nonatomic) NSTextField *label;
@property (nonatomic) NSImage *image;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSTimer *hideTimer;
@end

@implementation DPCaptureToast
- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    self.layerUsesCoreImageFilters = YES;
    self.layer.shadowOpacity = 0.2;
    self.layer.shadowRadius = 10;
    self.layer.shadowOffset = CGSizeMake(0, -3);
    self.alphaValue = 0;
    NSView *clip = [[NSView alloc] initWithFrame:self.bounds];
    clip.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    clip.wantsLayer = YES;
    clip.layer.cornerRadius = DPToastRadius;
    clip.layer.cornerCurve = kCACornerCurveContinuous;
    clip.layer.borderWidth = 1;
    clip.layer.borderColor = [NSColor colorWithWhite:1 alpha:0.1].CGColor;
    clip.layer.masksToBounds = YES;
    NSView *fill = DPMakeProfileBackground(), *veil = [[NSView alloc] initWithFrame:self.bounds];
    veil.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    veil.wantsLayer = YES;
    veil.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.05].CGColor;  // Dia's toast sits a shade lighter than its profile color.
    [clip addSubview:fill];
    [clip addSubview:veil];
    [self addSubview:clip];
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"checkmark.circle" accessibilityDescription:nil]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium];
    icon.contentTintColor = NSColor.labelColor;
    self.label = [NSTextField labelWithString:@"Screenshot Copied to Clipboard"];
    self.label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.label.textColor = NSColor.labelColor;
    CGFloat saveHeight = DPToastHeight - 2 * DPToastInset;
    NSButton *save = [NSButton buttonWithTitle:@"Save" target:self action:@selector(save:)];
    save.bordered = NO;
    save.attributedTitle = [[NSAttributedString alloc] initWithString:@"Save" attributes:@{ NSFontAttributeName : [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold], NSForegroundColorAttributeName : NSColor.labelColor }];
    save.wantsLayer = YES;
    save.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.12].CGColor;
    save.layer.cornerRadius = DPToastRadius - DPToastInset;
    save.layer.cornerCurve = kCACornerCurveContinuous;
    [save.heightAnchor constraintEqualToConstant:saveHeight].active = YES;
    [save.widthAnchor constraintEqualToConstant:ceil(save.intrinsicContentSize.width) + 20].active = YES;
    NSStackView *stack = [NSStackView stackViewWithViews:@[ icon, self.label, save ]];
    stack.spacing = 10;
    [stack setCustomSpacing:12 afterView:self.label];
    stack.edgeInsets = NSEdgeInsetsMake(0, DPToastPadding, 0, DPToastInset);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];
    return self;
}

- (void)dealloc { [_hideTimer invalidate]; }

- (void)save:(id)sender {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:[self.image CGImageForProposedRect:NULL context:nil hints:nil]];
    NSURL *url = DPSaveURL(self.title);
    if (![[rep representationUsingType:NSBitmapImageFileTypeJPEG properties:@{ NSImageCompressionFactor : @0.92 }] writeToURL:url atomically:YES]) return NSBeep();
    [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ url ]];
    [self fadeOut];
}

- (NSRect)frameIn:(NSView *)pane {
    NSView *bar = DPFindView(pane, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaToolbar); });
    CGFloat width = ceil(self.fittingSize.width), top = (bar ? NSHeight(bar.frame) : 0) - DPToastHeight / 2;  // On the toolbar's edge, as Dia's toasts are.
    CGFloat y = pane.isFlipped ? top : NSHeight(pane.bounds) - top - DPToastHeight;
    return NSMakeRect(round(NSMidX(pane.bounds) - width / 2), y, width, DPToastHeight);
}

- (void)animate:(BOOL)shown completion:(void (^)(void))completion {
    NSView *pane = self.superview;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPToastFade;
        self.animator.alphaValue = shown;
        self.animator.frame = [self frameIn:pane];
    } completionHandler:completion];
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    blur.name = @"blur";
    [blur setValue:@0 forKey:kCIInputRadiusKey];
    self.layer.filters = @[ blur ];
    CABasicAnimation *focus = [CABasicAnimation animationWithKeyPath:@"filters.blur.inputRadius"];
    focus.fromValue = shown ? @(DPToastBlur) : @0;
    focus.toValue = shown ? @0 : @(DPToastBlur);
    focus.duration = DPToastFade;
    focus.fillMode = kCAFillModeForwards;
    focus.removedOnCompletion = shown;
    [self.layer addAnimation:focus forKey:@"focus"];
}

- (void)fadeOut {
    [self.hideTimer invalidate];
    __weak DPCaptureToast *weakSelf = self;
    [self animate:NO completion:^{ if (weakSelf.alphaValue == 0) [weakSelf removeFromSuperview]; }];
}

- (void)showIn:(NSView *)pane {
    [self.hideTimer invalidate];
    self.appearance = DPProfileAppearance(pane.window);
    if (self.superview != pane) self.frame = [self frameIn:pane];
    [pane addSubview:self positioned:NSWindowAbove relativeTo:nil];
    [self animate:YES completion:nil];
    __weak DPCaptureToast *weakSelf = self;
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:DPToastFade + DPToastHold repeats:NO block:^(NSTimer *timer) { [weakSelf fadeOut]; }];
}
@end

void DPShowCaptureToast(NSView *pane, NSImage *image, NSString *title) {
    DPCaptureToast *toast = DPGet(pane, &DPToastKey);
    if (!toast) DPSet(pane, &DPToastKey, toast = [DPCaptureToast new]);
    toast.image = image;
    toast.title = title;
    [toast showIn:pane];
}
