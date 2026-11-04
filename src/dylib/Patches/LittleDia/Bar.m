#import "Bar.h"
#import <objc/message.h>

@implementation DPLittleBar
- (void)dealloc { [_timer invalidate]; }
@end

char DPBarKey;
static char DPHiddenByUsKey;
static const CGFloat DPAddressHeight = 30;

// The page has no change notifications that reach here, so the bar looks at it a few times a second.
static void DPUpdateButtons(DPLittleBar *bar) {
    id page = DPLittleDiaPage(bar.title.window);
    BOOL (*flag)(id, SEL) = (void *)objc_msgSend;
    bar.leading[1].enabled = page && flag(page, @selector(canGoBack));
    bar.leading[2].enabled = page && flag(page, @selector(canGoForward));
    bar.leading[3].enabled = page != nil;
}

DPLittleBar *DPMakeBar(NSView *title) {
    DPLittleBar *bar = [DPLittleBar new];
    bar.title = title;
    __weak NSView *weakTitle = title;
    bar.leading = @[
        DPMakeBarButton(@"xmark", @"Close", nil, ^{ [weakTitle.window performClose:nil]; }),
        DPMakeBarButton(@"chevron.left", @"Back", nil, ^{ DPLittleDiaGo(weakTitle.window, @selector(goBack)); }),
        DPMakeBarButton(@"chevron.right", @"Forward", nil, ^{ DPLittleDiaGo(weakTitle.window, @selector(goForward)); }),
        DPMakeBarButton(@"arrow.clockwise", @"Reload", @"r", ^{ DPLittleDiaGo(weakTitle.window, @selector(reload)); }),
    ];
    bar.open = DPMakeOpenInDiaButton(^{
        if (DPSendToLittleDia(@{@"action" : @"promote", @"url" : DPLittleDiaURL(weakTitle.window)})) DPPromoteLittleDiaWindow(weakTitle.window);
        else NSBeep();
    });
    bar.address = DPMakeAddressView(title);
    bar.divider = DPMakeDivider();
    __weak DPLittleBar *weakBar = bar;
    bar.timer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) {
        if (!weakBar.title.window) return;
        DPUpdateButtons(weakBar);
        DPRefreshAddressView(weakBar.address);
        DPMatchPage(weakBar.title.superview, DPLittleDiaPage(weakBar.title.window));
    }];
    return bar;
}

void DPPlaceBar(DPLittleBar *bar) {
    NSView *title = bar.title, *row = title.superview;
    CGFloat mid = NSMidY(title.frame);
    [bar.leading enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger i, BOOL *stop) {
        if (button.superview != row) [row addSubview:button];
        button.frame = NSMakeRect(DPInset + i * (DPButton + DPGap), round(mid - DPButton / 2), DPButton, DPButton);
    }];
    NSSize open = bar.open.intrinsicContentSize;
    if (bar.open.superview != row) [row addSubview:bar.open];
    // The same gap above it as beside it, and corners that follow the window's.
    CGFloat top = round(mid - open.height / 2), gap = NSHeight(row.bounds) - NSMaxY(NSMakeRect(0, top, 0, open.height));
    bar.open.frame = NSMakeRect(NSWidth(row.bounds) - gap - open.width, top, open.width, open.height);
    CGFloat corner = [row.window respondsToSelector:@selector(_cornerRadius)] ? ((CGFloat (*)(id, SEL))objc_msgSend)(row.window, @selector(_cornerRadius)) : 16;
    bar.open.layer.cornerRadius = MIN(open.height / 2, MAX(4, corner - gap));
    // Dia's address stays, unseen, so its frame keeps telling this layout where the address belongs.
    title.alphaValue = 0;
    if (bar.address.superview != row) [row addSubview:bar.address positioned:NSWindowAbove relativeTo:title];
    bar.address.frame = NSMakeRect(NSMinX(title.frame), round(mid - DPAddressHeight / 2), NSWidth(title.frame), DPAddressHeight);
    CGFloat hairline = 1 / MAX(1, row.window.backingScaleFactor);
    if (bar.divider.superview != row) [row addSubview:bar.divider];
    bar.divider.frame = NSMakeRect(0, row.isFlipped ? NSHeight(row.bounds) - hairline : 0, NSWidth(row.bounds), hairline);
    for (NSView *view in row.subviews)
        if (DPHasLabel(view, @"Downloads") && !view.hidden) {
            view.hidden = YES;
            DPSet(view, &DPHiddenByUsKey, @YES);
        }
    DPUpdateButtons(bar);
}

void DPRemoveBar(NSView *title) {
    DPLittleBar *bar = DPGet(title, &DPBarKey);
    if (!bar) return;
    DPSet(title, &DPBarKey, nil);
    [bar.timer invalidate];
    for (NSView *view in [bar.leading arrayByAddingObjectsFromArray:@[ bar.open ]]) [view removeFromSuperview];
    [bar.address removeFromSuperview];
    [bar.divider removeFromSuperview];
    title.alphaValue = 1;
    DPMatchPage(title.superview, nil);
    for (NSView *view in title.superview.subviews)
        if ([DPGet(view, &DPHiddenByUsKey) boolValue]) {
            view.hidden = NO;
            DPSet(view, &DPHiddenByUsKey, nil);
        }
}

