#import "TabIntegrations.h"

@interface DPTabIntegrationRowView : NSView
@property(nonatomic, copy) void (^open)(void), (^pin)(void);
@property(nonatomic, strong) NSTrackingArea *hoverArea;
@end

@implementation DPTabIntegrationRowView
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point {
    if (![super hitTest:point]) return nil;
    NSPoint local = [self convertPoint:point fromView:self.superview];
    for (NSView *child in self.subviews)
        if ([child isKindOfClass:NSButton.class] && ((NSButton *)child).action == @selector(pinRow:)
            && NSPointInRect(local, child.frame)) return child;
    return self;
}
- (void)mouseDown:(NSEvent *)event { if (self.open) self.open(); }
- (void)openRow:(id)sender { if (self.open) self.open(); }
- (void)pinRow:(id)sender { if (self.pin) self.pin(); }
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.hoverArea) [self removeTrackingArea:self.hoverArea];
    self.hoverArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect
        owner:self userInfo:nil];
    [self addTrackingArea:self.hoverArea];
}
- (void)mouseEntered:(NSEvent *)event {
    self.wantsLayer = YES;
    self.layer.cornerRadius = 6;
    self.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:0.06].CGColor;
}
- (void)mouseExited:(NSEvent *)event { self.layer.backgroundColor = NSColor.clearColor.CGColor; }
@end

NSView *DPTabIntegrationRow(NSString *title, BOOL working, BOOL unread, BOOL pinned,
                            void (^open)(void), void (^pin)(void)) {
    DPTabIntegrationRowView *row = [[DPTabIntegrationRowView alloc] initWithFrame:NSMakeRect(0, 0, 256, 36)];
    row.open = open;
    row.pin = pin;
    unread = unread && !working;
    NSFont *font = [NSFont systemFontOfSize:13];
    CGFloat titleWidth = MIN(192, ceil([title sizeWithAttributes:@{NSFontAttributeName:font}].width) + 4);

    NSButton *link = [[NSButton alloc] initWithFrame:NSMakeRect(4, 0, titleWidth, 36)];
    link.title = title;
    link.font = font;
    link.alignment = NSTextAlignmentLeft;
    link.bordered = NO;
    link.lineBreakMode = NSLineBreakByTruncatingTail;
    link.cell.wraps = NO;
    link.cell.scrollable = NO;
    link.target = row;
    link.action = @selector(openRow:);
    link.toolTip = title;
    link.accessibilityLabel = [NSString stringWithFormat:@"%@%@%@", title,
        working ? @", working" : @"", unread ? @", unread" : @""];
    [row addSubview:link];

    CGFloat statusX = NSMaxX(link.frame) + 8;
    if (working) {
        NSProgressIndicator *spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(statusX, 10, 16, 16)];
        spinner.style = NSProgressIndicatorStyleSpinning;
        spinner.controlSize = NSControlSizeSmall;
        spinner.displayedWhenStopped = NO;
        spinner.accessibilityLabel = @"Working";
        [row addSubview:spinner];
        [spinner startAnimation:nil];
    }
    if (unread) {
        NSView *dot = [[NSView alloc] initWithFrame:NSMakeRect(statusX + 5, 15, 6, 6)];
        dot.wantsLayer = YES;
        dot.layer.cornerRadius = 3;
        dot.layer.backgroundColor = NSColor.systemBlueColor.CGColor;
        dot.accessibilityElement = YES;
        dot.accessibilityLabel = @"Unread";
        [row addSubview:dot];
    }

    if (pin) {
        NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(228, 4, 28, 28)];
        button.bordered = NO;
        button.image = [NSImage imageWithSystemSymbolName:pinned ? @"pin.fill" : @"pin" accessibilityDescription:nil];
        button.contentTintColor = pinned ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
        button.target = row;
        button.action = @selector(pinRow:);
        button.toolTip = pinned ? @"Unpin" : @"Pin";
        button.accessibilityLabel = button.toolTip;
        [row addSubview:button];
    }
    return row;
}
