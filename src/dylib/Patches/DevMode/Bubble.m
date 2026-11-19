#import "Controls.h"

static const CGFloat DPArrowWidth = 24, DPArrowHeight = 10, DPBubbleRadius = 14, DPBubbleScale = 0.94;
static const NSTimeInterval DPBubbleFade = 0.18;

@interface DPBubblePanel : NSPanel
@end
@implementation DPBubblePanel
- (BOOL)canBecomeKeyWindow { return NO; }
@end

@interface DPBubbleView : NSView
@property (nonatomic) CGFloat arrowX;
@end

@implementation DPBubbleView
- (BOOL)isFlipped { return YES; }
- (NSBezierPath *)outline {
    NSRect body = NSMakeRect(0.5, DPArrowHeight + 0.5, NSWidth(self.bounds) - 1, NSHeight(self.bounds) - DPArrowHeight - 1);
    CGFloat top = NSMinY(body), x = self.arrowX, r = DPBubbleRadius;
    NSBezierPath *path = [NSBezierPath new];
    [path moveToPoint:NSMakePoint(NSMinX(body) + r, top)];
    [path lineToPoint:NSMakePoint(x - DPArrowWidth / 2, top)];
    [path curveToPoint:NSMakePoint(x, 0.5) controlPoint1:NSMakePoint(x - DPArrowWidth / 4, top) controlPoint2:NSMakePoint(x - 2, 0.5)];
    [path curveToPoint:NSMakePoint(x + DPArrowWidth / 2, top) controlPoint1:NSMakePoint(x + 2, 0.5) controlPoint2:NSMakePoint(x + DPArrowWidth / 4, top)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(body), top) toPoint:NSMakePoint(NSMaxX(body), NSMaxY(body)) radius:r];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(body), NSMaxY(body)) toPoint:NSMakePoint(NSMinX(body), NSMaxY(body)) radius:r];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(body), NSMaxY(body)) toPoint:NSMakePoint(NSMinX(body), top) radius:r];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(body), top) toPoint:NSMakePoint(NSMinX(body) + r, top) radius:r];
    [path closePath];
    return path;
}
- (void)drawRect:(NSRect)dirty {
    NSBezierPath *outline = self.outline;
    [[NSColor colorWithSRGBRed:0.11 green:0.11 blue:0.12 alpha:1] setFill];
    [outline fill];
    [[NSColor colorWithWhite:1 alpha:0.1] setStroke];
    [outline stroke];
}
@end

static DPBubblePanel *DPBubble;
static NSArray *DPBubbleMonitors;

void DPCloseBubble(void) {
    for (id monitor in DPBubbleMonitors) [NSEvent removeMonitor:monitor];
    DPBubbleMonitors = nil;
    [DPBubble orderOut:nil];
    DPBubble = nil;
}

BOOL DPBubbleShown(void) { return DPBubble != nil; }

static BOOL DPMouseNear(NSView *view) {
    if (!view.window) return NO;
    NSRect screen = [view.window convertRectToScreen:[view convertRect:view.bounds toView:nil]];
    return NSPointInRect(NSEvent.mouseLocation, NSInsetRect(screen, -8, -8));
}

static void DPCloseWhenMouseLeaves(NSPanel *panel, NSView *anchor) {
    __block NSInteger away = 0;
    [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        if (DPBubble != panel) return [timer invalidate];
        away = DPMouseNear(anchor) || DPMouseNear(panel.contentView) ? 0 : away + 1;
        if (away >= 4) DPCloseBubble();
    }];
}

void DPShowBubble(NSView *anchor, NSView *content) {
    DPCloseBubble();
    NSSize size = content.fittingSize;
    size.height += DPArrowHeight;
    NSRect target = [anchor.window convertRectToScreen:[anchor convertRect:anchor.bounds toView:nil]];
    NSRect visible = (anchor.window.screen ?: NSScreen.mainScreen).visibleFrame;
    CGFloat x = MAX(NSMinX(visible) + 8, MIN(NSMaxX(visible) - size.width - 8, round(NSMidX(target) - size.width / 2)));
    NSRect frame = NSMakeRect(x, NSMinY(target) - 2 - size.height, size.width, size.height);
    DPBubble = [[DPBubblePanel alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    DPBubble.opaque = NO;
    DPBubble.backgroundColor = NSColor.clearColor;
    DPBubble.hasShadow = YES;
    DPBubble.level = NSPopUpMenuWindowLevel;
    DPBubble.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    DPBubbleView *view = [[DPBubbleView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
    view.arrowX = NSMidX(target) - x;
    content.frame = NSMakeRect(0, DPArrowHeight, size.width, size.height - DPArrowHeight);
    [view addSubview:content];
    DPBubble.contentView = view;
    DPBubble.animationBehavior = NSWindowAnimationBehaviorNone;
    DPBubble.alphaValue = 0;
    [DPBubble orderFront:nil];
    [DPBubble invalidateShadow];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPBubbleFade;
        DPBubble.animator.alphaValue = 1;
    }];
    view.wantsLayer = YES;
    CATransform3D grow = CATransform3DMakeTranslation(view.arrowX, size.height, 0);
    grow = CATransform3DScale(grow, DPBubbleScale, DPBubbleScale, 1);
    grow = CATransform3DTranslate(grow, -view.arrowX, -size.height, 0);
    CABasicAnimation *open = [CABasicAnimation animationWithKeyPath:@"transform"];
    open.fromValue = [NSValue valueWithCATransform3D:grow];
    open.duration = DPBubbleFade;
    open.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.2 :0.9 :0.3 :1];
    [view.layer addAnimation:open forKey:@"open"];
    NSPanel *panel = DPBubble;
    DPBubbleMonitors = @[
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
            if (event.type == NSEventTypeKeyDown ? event.keyCode == 53 : event.window != panel) DPCloseBubble();
            return event.type == NSEventTypeKeyDown && event.keyCode == 53 ? nil : event;
        }],
        [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown handler:^(NSEvent *event) { DPCloseBubble(); }],
    ];
    DPCloseWhenMouseLeaves(panel, anchor);
}
