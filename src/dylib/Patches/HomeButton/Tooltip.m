#import "HomeButton.h"

// Dia's own toolbar tooltips are SwiftUI a patch can't reach, so the house shows one built to match: a 27 pt pill of
// 12 pt text centered 4 pt under the button, after the pointer rests on it for a moment.
static const CGFloat DPTipHeight = 27, DPTipPadding = 8, DPTipGap = 4, DPTipMargin = 12;
static const NSTimeInterval DPTipDelay = 0.6;

@interface DPHomeTipView : NSView
@property (nonatomic, strong) NSTextField *label;
@end

@implementation DPHomeTipView
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 6;
    self.layer.borderWidth = 0.5;
    self.layer.shadowOpacity = 0.25;
    self.layer.shadowRadius = 3;
    self.layer.shadowOffset = CGSizeMake(0, -2);
    _label = [NSTextField labelWithString:@""];
    _label.font = [NSFont systemFontOfSize:12];
    [self addSubview:_label];
    return self;
}
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    BOOL dark = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
    self.layer.backgroundColor = (dark ? [NSColor colorWithWhite:0.15 alpha:1] : [NSColor colorWithWhite:0.98 alpha:1]).CGColor;
    self.layer.borderColor = (dark ? [NSColor colorWithWhite:1 alpha:0.1] : [NSColor colorWithWhite:0 alpha:0.1]).CGColor;
    self.label.textColor = dark ? [NSColor colorWithWhite:1 alpha:0.85] : [NSColor colorWithWhite:0 alpha:0.85];
}
@end

static NSPanel *DPTipPanel;
static DPHomeTipView *DPTip;
static NSTimer *DPTipTimer;

static NSPanel *DPTipWindow(void) {
    if (DPTipPanel) return DPTipPanel;
    DPTipPanel = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                              backing:NSBackingStoreBuffered defer:YES];
    DPTipPanel.opaque = NO;
    DPTipPanel.backgroundColor = NSColor.clearColor;
    DPTipPanel.hasShadow = NO;
    DPTipPanel.ignoresMouseEvents = YES;
    DPTipPanel.releasedWhenClosed = NO;
    DPTip = [[DPHomeTipView alloc] initWithFrame:NSZeroRect];
    [DPTipPanel.contentView addSubview:DPTip];
    return DPTipPanel;
}

void DPHideHomeTip(void) {
    [DPTipTimer invalidate];
    DPTipTimer = nil;
    if (!DPTipPanel.visible) return;
    [DPTipPanel.parentWindow removeChildWindow:DPTipPanel];
    [DPTipPanel orderOut:nil];
}

static void DPShowTipNow(NSView *button, NSString *text) {
    NSWindow *window = button.window;
    if (!window || button.hiddenOrHasHiddenAncestor) return;
    NSPanel *panel = DPTipWindow();
    DPHomeTipView *tip = DPTip;
    tip.appearance = button.effectiveAppearance;
    tip.needsDisplay = YES;
    tip.label.stringValue = text;
    [tip.label sizeToFit];
    CGFloat width = ceil(NSWidth(tip.label.frame)) + 2 * DPTipPadding;
    NSRect anchor = [window convertRectToScreen:[button convertRect:button.bounds toView:nil]];
    // The panel leaves room around the pill for its shadow.
    NSRect frame = NSMakeRect(round(NSMidX(anchor) - width / 2) - DPTipMargin, NSMinY(anchor) - DPTipGap - DPTipHeight - DPTipMargin,
                              width + 2 * DPTipMargin, DPTipHeight + 2 * DPTipMargin);
    [panel setFrame:frame display:NO];
    tip.frame = NSInsetRect(panel.contentView.bounds, DPTipMargin, DPTipMargin);
    tip.label.frameOrigin = NSMakePoint(DPTipPadding, round((DPTipHeight - NSHeight(tip.label.frame)) / 2));
    if (panel.parentWindow != window) {
        [panel.parentWindow removeChildWindow:panel];
        [window addChildWindow:panel ordered:NSWindowAbove];
    }
    [panel orderFront:nil];
}

void DPShowHomeTip(NSView *button, NSString *text) {
    DPHideHomeTip();
    __weak NSView *weakButton = button;
    DPTipTimer = [NSTimer scheduledTimerWithTimeInterval:DPTipDelay repeats:NO block:^(NSTimer *timer) {
        DPTipTimer = nil;
        NSView *strong = weakButton;
        if (strong) DPShowTipNow(strong, text);
    }];
}
