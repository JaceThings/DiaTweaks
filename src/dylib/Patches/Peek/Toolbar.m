#import "Patches/Peek/Peek.h"
#import "Patches/LittleDia/LittleDia.h"

// A bar across the top of the card, built from Little Dia's own parts so the two look and behave alike: its buttons,
// its divider and its page color, with the Peek's address and Dia's loading glow.
const CGFloat DPPeekToolbarHeight = 38;
static const CGFloat DPInset = 6, DPGap = 2, DPButton = 28, DPAddressHeight = 30;  // Little Dia's.

@interface DPPeekToolbar : NSView
@property (nonatomic, weak) id page;
@property (nonatomic, strong) NSView *row, *divider, *address, *glow;
@property (nonatomic, strong) NSArray<NSButton *> *buttons;  // back, forward, reload
@property (nonatomic, strong) NSTimer *watch;
@end

@implementation DPPeekToolbar
- (BOOL)wantsUpdateLayer { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {}  // Not the card's, which closes it.

- (instancetype)initWithPage:(id)page {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.page = page;
    self.wantsLayer = YES;
    self.layer.masksToBounds = YES;
    // Little Dia colors the row it sits in; this one sits on the card's own background, so the bar stays opaque.
    self.row = [NSView new];
    __weak DPPeekToolbar *weak = self;
    self.buttons = @[
        DPMakeBarButton(@"chevron.left", @"Back", nil, ^{ DPPeekNavigate(weak.page, DPPeekBack); }),
        DPMakeBarButton(@"chevron.right", @"Forward", nil, ^{ DPPeekNavigate(weak.page, DPPeekForward); }),
        DPMakeBarButton(@"arrow.clockwise", @"Reload", nil, ^{ DPPeekNavigate(weak.page, DPPeekReload); }),
    ];
    self.address = DPPeekAddressFor(page);
    self.glow = DPPeekGlowFor(page);
    self.divider = DPMakeDivider();
    NSArray<NSView *> *parts = [(NSArray<NSView *> *)self.buttons arrayByAddingObjectsFromArray:@[self.address, self.glow, self.divider]];
    for (NSView *view in parts) [self.row addSubview:view];
    [self addSubview:self.row];
    [self refresh];
    return self;
}

- (void)updateLayer { self.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor; }

- (void)layout {
    [super layout];
    // Laid out at full height from the top, so the bar is cropped, not squeezed, as it shrinks into a tab.
    CGFloat h = NSHeight(self.bounds), full = DPPeekToolbarHeight;
    self.row.frame = NSMakeRect(0, h - full, NSWidth(self.bounds), full);
    CGFloat mid = full / 2, x = DPInset;
    for (NSButton *button in self.buttons) {
        button.frame = NSMakeRect(x, round(mid - DPButton / 2), DPButton, DPButton);
        x += DPButton + DPGap;
    }
    x += DPInset - DPGap;
    self.address.frame = NSMakeRect(x, round(mid - DPAddressHeight / 2), MAX(0, NSWidth(self.row.bounds) - x - DPInset), DPAddressHeight);
    self.divider.frame = NSMakeRect(0, 0, NSWidth(self.row.bounds), 1 / MAX(1, self.window.backingScaleFactor));
    self.glow.frame = NSMakeRect(0, 0, NSWidth(self.row.bounds), MIN(full, 24));
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self.watch invalidate];
    self.watch = nil;
    if (!self.window) return;
    __weak DPPeekToolbar *weak = self;
    self.watch = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) { [weak refresh]; }];
}

// As Little Dia's bar does: the page has no change notifications that reach here.
- (void)refresh {
    NSObject *page = self.page;
    if (!page) return;
    self.buttons[0].enabled = [[page valueForKey:@"canGoBack"] boolValue];
    self.buttons[1].enabled = [[page valueForKey:@"canGoForward"] boolValue];
    DPPeekRefreshAddress(self.address);
    DPMatchPage(self.row, page);
}
@end

NSView *DPPeekToolbarFor(id page) { return [[DPPeekToolbar alloc] initWithPage:page]; }
NSView *DPPeekToolbarAddress(NSView *toolbar) { return [toolbar isKindOfClass:DPPeekToolbar.class] ? ((DPPeekToolbar *)toolbar).address : nil; }

void DPPeekNavigate(id page, DPPeekStep step) {
    if (step == DPPeekStop) return (void)[page performSelector:@selector(stop)];
    id navigation = [(NSObject *)page valueForKey:@"navigationController"];
    if (step == DPPeekBack && [[(NSObject *)page valueForKey:@"canGoBack"] boolValue]) [navigation performSelector:@selector(goBack)];
    else if (step == DPPeekForward && [[(NSObject *)page valueForKey:@"canGoForward"] boolValue]) [navigation performSelector:@selector(goForward)];
    else if (step == DPPeekReload) [navigation performSelector:@selector(reload)];
}
