#import "TidyTabs.h"

// SF Symbols has no broom, so it's drawn: a handle, a collar and a fan of bristles, leaning right. `size` is in points.
static NSImage *DPBroomImage(CGFloat size) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(size, size) flipped:YES drawingHandler:^BOOL(NSRect rect) {
        NSAffineTransform *tilt = [NSAffineTransform transform];
        [tilt scaleBy:size / 14];
        [tilt translateXBy:7 yBy:7];
        [tilt rotateByDegrees:25];
        [tilt translateXBy:-7 yBy:-7];
        [tilt concat];
        [NSColor.blackColor set];
        NSBezierPath *handle = [NSBezierPath bezierPath];
        handle.lineWidth = 1.5;
        handle.lineCapStyle = NSLineCapStyleRound;
        [handle moveToPoint:NSMakePoint(7, 0.75)];
        [handle lineToPoint:NSMakePoint(7, 7)];
        [handle stroke];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(4.5, 6.5, 5, 2) xRadius:0.75 yRadius:0.75] fill];
        NSBezierPath *bristles = [NSBezierPath bezierPath];
        [bristles moveToPoint:NSMakePoint(4.25, 9)];
        [bristles lineToPoint:NSMakePoint(9.75, 9)];
        [bristles lineToPoint:NSMakePoint(11.5, 13.5)];
        [bristles lineToPoint:NSMakePoint(2.5, 13.5)];
        [bristles closePath];
        [bristles fill];
        return YES;
    }];
    image.template = YES;
    image.accessibilityDescription = @"Tidy Tabs";
    return image;
}

static BOOL DPBrushesBusy;

NSHashTable<DPTidyBrush *> *DPTidyBrushes(void) {
    static NSHashTable *brushes;
    if (!brushes) brushes = [NSHashTable weakObjectsHashTable];
    return brushes;
}

BOOL DPTidyIsBusy(void) { return DPBrushesBusy; }

// The row stays open while the model works, so its wave stays in view; after, it follows the pointer again.
void DPTidyBrushesBusy(BOOL busy) {
    DPBrushesBusy = busy;
    for (DPTidyBrush *brush in DPTidyBrushes()) [brush showBusy];
    for (NSView *list in DPFindViews(DPDiaTabList)) {
        DPTidyRowIn(list, NO).needsLayout = YES;
        NSView *separator = DPTidySeparatorIn(list);
        if (separator) DPPlaceSeparatorBrush(separator);
        if (!busy) [[DPTidyHover forList:list] track];
    }
}

@interface DPTidyBrush ()
@property (nonatomic, strong) NSPopover *why;
@property (nonatomic, strong) NSTimer *whyTimer;
@end

@implementation DPTidyBrush

- (instancetype)init {
    if (!(self = [super initWithFrame:NSMakeRect(0, 0, DPTidyBrushSize, DPTidyBrushSize)])) return nil;
    self.bordered = NO;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 6;
    self.image = DPBroomImage(14);
    self.imagePosition = NSImageOnly;
    self.accessibilityLabel = @"Tidy Tabs";
    self.toolTip = @"Tidy Tabs";
    self.target = self;
    self.action = @selector(tidy:);
    [DPTidyBrushes() addObject:self];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    [self restyle];
    return self;
}

- (void)tidy:(id)sender {
    if (DPTidyUnavailableReason()) return [self showWhy];
    DPTidyTabsNow(self.window);
}

// The broom looks the same while the model works; the divider's wave shows it, and a click then does nothing.
- (void)showBusy {
    self.toolTip = DPBrushesBusy ? @"Tidying…" : DPTidyUnavailableReason() ? nil : @"Tidy Tabs";
}

// Without Apple Intelligence a click can't tidy, so pointing at the broom says why in a glass bubble, like System Settings.
- (void)showWhy {
    NSString *reason = DPTidyUnavailableReason();
    if (!reason || self.why.shown || !self.window) return;
    NSTextField *label = [NSTextField wrappingLabelWithString:reason];
    label.preferredMaxLayoutWidth = 220;
    NSView *content = [NSView new];
    [content addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12],
        [label.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [label.topAnchor constraintEqualToAnchor:content.topAnchor constant:8],
        [label.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-8],
    ]];
    content.frame = (NSRect){NSZeroPoint, content.fittingSize};  // Sized up front, or the popover opens as a sliver.
    self.why = [NSPopover new];
    self.why.contentViewController = [NSViewController new];
    self.why.contentViewController.view = content;
    self.why.contentViewController.preferredContentSize = content.frame.size;
    self.why.behavior = NSPopoverBehaviorApplicationDefined;
    [self.why showRelativeToRect:self.bounds ofView:self preferredEdge:self.isFlipped ? NSRectEdgeMinY : NSRectEdgeMaxY];
}

- (void)hideWhy {
    [self.whyTimer invalidate];
    self.whyTimer = nil;
    [self.why close];
}

- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self showBusy]; if (!self.window) [self hideWhy]; }

- (void)restyle {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        // Plain matches Close All: tertiary when idle, secondary under the pointer.
        if (self.plain) self.contentTintColor = self.hovered ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor;
        else self.contentTintColor = self.hovered ? NSColor.labelColor : NSColor.secondaryLabelColor;
        self.layer.backgroundColor = self.hovered && !self.plain ? NSColor.quaternaryLabelColor.CGColor : NSColor.clearColor.CGColor;
    }];
}

- (void)setHovered:(BOOL)hovered { _hovered = hovered; [self restyle]; }
- (void)setPlain:(BOOL)plain {
    _plain = plain;
    self.image = DPBroomImage(plain ? 11 : 14);
    [self restyle];
}
- (void)mouseEntered:(NSEvent *)event {
    [self showBusy];
    self.hovered = YES;
    __weak DPTidyBrush *weakSelf = self;
    if (DPTidyUnavailableReason()) self.whyTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer *timer) { [weakSelf showWhy]; }];
}
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; [self hideWhy]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self restyle]; }
@end
