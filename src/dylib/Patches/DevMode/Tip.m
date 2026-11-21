#import "Controls.h"

static const CGFloat DPTipHeight = 26, DPTipRadius = 6, DPKey = 18, DPTipGap = 5;
static NSPanel *DPTipPanel;
static NSUInteger DPTipGeneration;

@interface DPTipView : NSStackView
@end

@implementation DPTipView
- (void)drawRect:(NSRect)dirty {
    NSBezierPath *shape = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5) xRadius:DPTipRadius yRadius:DPTipRadius];
    [[NSColor colorWithWhite:0.12 alpha:1] setFill];
    [shape fill];
    [[NSColor colorWithWhite:1 alpha:0.12] setStroke];
    [shape stroke];
}
@end

static NSView *DPKeyCap(NSString *key) {
    NSTextField *label = [NSTextField labelWithString:key];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.textColor = [NSColor colorWithWhite:0.85 alpha:1];
    label.alignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *cap = [NSView new];
    cap.wantsLayer = YES;
    cap.layer.cornerRadius = 4;
    cap.layer.backgroundColor = [NSColor colorWithWhite:0.36 alpha:1].CGColor;
    [cap addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [cap.widthAnchor constraintEqualToConstant:DPKey], [cap.heightAnchor constraintEqualToConstant:DPKey],
        [label.centerXAnchor constraintEqualToAnchor:cap.centerXAnchor], [label.centerYAnchor constraintEqualToAnchor:cap.centerYAnchor],
    ]];
    return cap;
}

static NSView *DPTipContent(NSString *text, NSString *keys) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    label.textColor = [NSColor colorWithWhite:0.9 alpha:1];
    DPTipView *tip = [DPTipView stackViewWithViews:@[ label ]];
    tip.spacing = 3;
    [tip setCustomSpacing:8 afterView:label];
    for (NSUInteger i = 0; i < keys.length; i++) [tip addArrangedSubview:DPKeyCap([keys substringWithRange:NSMakeRange(i, 1)])];
    CGFloat side = (DPTipHeight - DPKey) / 2;
    tip.edgeInsets = NSEdgeInsetsMake(0, 8, 0, keys.length ? side : 8);
    [tip.heightAnchor constraintEqualToConstant:DPTipHeight].active = YES;
    return tip;
}

void DPShowTip(NSView *anchor, NSString *text, NSString *keys) {
    if (!text.length || !anchor.window) return;
    NSUInteger generation = ++DPTipGeneration;
    BOOL quick = DPTipPanel.visible;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((quick ? 0 : 0.5) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation != DPTipGeneration || !anchor.window) return;
        if (!DPTipPanel) {
            DPTipPanel = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:YES];
            DPTipPanel.opaque = NO;
            DPTipPanel.backgroundColor = NSColor.clearColor;
            DPTipPanel.hasShadow = YES;
            DPTipPanel.ignoresMouseEvents = YES;
            DPTipPanel.level = NSPopUpMenuWindowLevel;
        }
        NSView *content = DPTipContent(text, keys);
        NSSize size = content.fittingSize;
        NSRect frame = [anchor.window convertRectToScreen:[anchor convertRect:anchor.bounds toView:nil]];
        DPTipPanel.contentView = content;
        [DPTipPanel setFrame:NSMakeRect(round(NSMidX(frame) - size.width / 2), NSMinY(frame) - DPTipGap - DPTipHeight, size.width, DPTipHeight) display:YES];
        [DPTipPanel invalidateShadow];
        if (DPTipPanel.visible) return;
        DPTipPanel.alphaValue = 0;
        [DPTipPanel orderFront:nil];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.12;
            DPTipPanel.animator.alphaValue = 1;
        }];
    });
}

void DPHideTip(void) {
    NSUInteger generation = ++DPTipGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation == DPTipGeneration) [DPTipPanel orderOut:nil];
    });
}
