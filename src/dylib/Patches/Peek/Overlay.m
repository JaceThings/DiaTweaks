#import "Peek.h"

@implementation DPPeekOverlay
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:0.42].CGColor;
    self.accessibilityRole = NSAccessibilityGroupRole;
    self.accessibilityLabel = @"Peek preview";
    _card = [NSView new];
    _card.wantsLayer = YES;
    _card.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
    _card.layer.cornerRadius = 14;
    _card.layer.masksToBounds = YES;
    [self addSubview:_card];
    _heading = [NSTextField labelWithString:@"Peek"];
    _heading.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _heading.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [_card addSubview:_heading];
    _closeButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:@"Close Peek"]
        target:self action:@selector(closePeek:)];
    _closeButton.bordered = NO;
    _closeButton.accessibilityLabel = @"Close Peek";
    [_card addSubview:_closeButton];
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = MAX(0, self.bounds.size.width * 0.85);
    CGFloat height = MAX(0, self.bounds.size.height - 80);
    self.card.frame = NSMakeRect((self.bounds.size.width - width) / 2, 40, width, height);
    self.host.frame = NSMakeRect(0, 0, width, MAX(0, height - 36));
    self.heading.frame = NSMakeRect(16, MAX(0, height - 26), MAX(0, width - 64), 18);
    self.closeButton.frame = NSMakeRect(MAX(0, width - 32), MAX(0, height - 30), 24, 24);
}
- (void)closePeek:(id)sender { if (self.dismiss) self.dismiss(); }
- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (!NSPointInRect(point, self.card.frame) && self.dismiss) self.dismiss();
}
@end
