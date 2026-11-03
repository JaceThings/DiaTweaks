#import "HideToolbar.h"

static const CGFloat DPLineHeight = 2;
static const NSTimeInterval DPLineFade = 0.3;
static char DPLineKey;

// A thin line along the top of the pane that fills as the page loads, then fades. It never takes the pointer.
@interface DPProgressLineView : NSView
@property (nonatomic, strong) CALayer *fill;
@property (nonatomic) CGFloat fraction;
@property (nonatomic) BOOL finishing;
@end

@implementation DPProgressLineView

- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    self.fill = [CALayer layer];  // Not a view's own layer, so it animates its frame by itself.
    [self.layer addSublayer:self.fill];
    return self;
}

- (BOOL)wantsUpdateLayer { return YES; }

- (void)updateLayer {
    self.fill.backgroundColor = [NSColor.controlAccentColor CGColor];  // Follows the accent color, light and dark.
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (NSRect)fillFrame { return NSMakeRect(0, 0, round(NSWidth(self.bounds) * self.fraction), DPLineHeight); }

- (void)layout {
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];  // Resizing with the window, not loading.
    self.fill.frame = self.fillFrame;
    [CATransaction commit];
}

- (void)setFraction:(CGFloat)fraction {
    _fraction = fraction;
    self.fill.frame = self.fillFrame;
}

- (void)placeIn:(NSView *)pane {
    self.frame = NSMakeRect(0, pane.isFlipped ? 0 : NSHeight(pane.bounds) - DPLineHeight, NSWidth(pane.bounds), DPLineHeight);
    self.autoresizingMask = NSViewWidthSizable | (pane.isFlipped ? NSViewMaxYMargin : NSViewMinYMargin);
    if (self.superview != pane || pane.subviews.lastObject != self) [pane addSubview:self positioned:NSWindowAbove relativeTo:nil];
}
@end

static DPProgressLineView *DPLineIn(NSView *pane) {
    DPProgressLineView *line = DPGet(pane, &DPLineKey);
    return line.superview == pane ? line : nil;
}

void DPShowProgressLine(NSView *pane, CGFloat fraction) {
    DPProgressLineView *line = DPGet(pane, &DPLineKey);
    if (!line) DPSet(pane, &DPLineKey, line = [DPProgressLineView new]);
    if (!DPLineIn(pane) || line.finishing) {
        // A new load starts from the left, without animating back from where the last one ended.
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        line.finishing = NO;
        line.fraction = 0;
        [CATransaction commit];
        line.alphaValue = 1;
    }
    [line placeIn:pane];
    line.fraction = MAX(line.fraction, fraction);  // Never runs backwards within a load.
}

// Fills the line, then fades it out.
void DPFinishProgressLine(NSView *pane) {
    DPProgressLineView *line = DPLineIn(pane);
    if (!line || line.finishing) return;
    line.finishing = YES;
    line.fraction = 1;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPLineFade;
        line.animator.alphaValue = 0;
    } completionHandler:^{
        if (line.finishing) [line removeFromSuperview];  // Unless another load brought it back.
    }];
}

void DPRemoveProgressLine(NSView *pane) {
    DPProgressLineView *line = DPGet(pane, &DPLineKey);
    line.finishing = NO;
    [line removeFromSuperview];
}

BOOL DPShowsProgressLine(NSView *pane) {
    for (NSView *view in pane.subviews)
        if ([view isKindOfClass:DPProgressLineView.class] && view.alphaValue > 0) return YES;
    return NO;
}
