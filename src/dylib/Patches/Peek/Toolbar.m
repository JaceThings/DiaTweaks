#import "Patches/Peek/Peek.h"

// A bar across the top of the card, like Little Dia's: back, forward, reload, and the page's site and title.
const CGFloat DPPeekToolbarHeight = 38;

@interface DPPeekToolbar : NSView
@property (nonatomic, weak) id page;
@property (nonatomic, strong) NSButton *back, *forward, *reload;
@property (nonatomic, strong) NSView *address;
@property (nonatomic, strong) CALayer *line;
@property (nonatomic, strong) NSTimer *watch;
@property (nonatomic) BOOL loading;
@end

static NSButton *DPPeekBarButton(NSString *symbol, NSString *label, id target, SEL action) {
    NSImage *image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label]
                      imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium]];
    NSButton *button = [NSButton buttonWithImage:image target:target action:action];
    button.bordered = NO;
    button.contentTintColor = NSColor.secondaryLabelColor;
    button.toolTip = label;
    return button;
}

@implementation DPPeekToolbar
- (BOOL)wantsUpdateLayer { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {}  // Not the card's, which closes it.

- (instancetype)initWithPage:(id)page {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.page = page;
    self.wantsLayer = YES;
    self.layer.masksToBounds = YES;
    self.line = [CALayer layer];
    [self.layer addSublayer:self.line];
    self.back = DPPeekBarButton(@"chevron.left", @"Back", self, @selector(goBack));
    self.forward = DPPeekBarButton(@"chevron.right", @"Forward", self, @selector(goForward));
    self.reload = DPPeekBarButton(@"arrow.clockwise", @"Reload", self, @selector(reloadOrStop));
    self.address = DPPeekAddressFor(page);
    for (NSView *view in @[self.back, self.forward, self.reload, self.address]) [self addSubview:view];
    [self refresh];
    return self;
}

- (void)updateLayer {
    self.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
    self.line.backgroundColor = NSColor.separatorColor.CGColor;
}

- (void)layout {
    [super layout];
    CGFloat h = NSHeight(self.bounds), side = 26, x = 10, mid = DPPeekToolbarHeight / 2;
    // Pinned to the top while the bar shrinks away as the card grows into a tab.
    CGFloat y = h - mid - side / 2;
    for (NSButton *button in @[self.back, self.forward, self.reload]) {
        button.frame = NSMakeRect(x, y, side, side);
        x += side + 4;
    }
    x += 4;
    self.address.frame = NSMakeRect(x, h - mid - 14, MAX(0, NSWidth(self.bounds) - x - 10), 28);
    self.line.frame = CGRectMake(0, 0, NSWidth(self.bounds), 1 / MAX(1, self.window.backingScaleFactor));
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self.watch invalidate];
    self.watch = nil;
    if (!self.window) return;
    __weak DPPeekToolbar *weak = self;
    self.watch = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) { [weak refresh]; }];
}

- (void)refresh {
    NSObject *page = self.page;
    if (!page) return;
    self.back.enabled = [[page valueForKey:@"canGoBack"] boolValue];
    self.forward.enabled = [[page valueForKey:@"canGoForward"] boolValue];
    BOOL loading = [[page valueForKey:@"isLoading"] boolValue];
    if (loading != self.loading) {
        self.loading = loading;
        NSString *label = loading ? @"Stop" : @"Reload";
        self.reload.image = [[NSImage imageWithSystemSymbolName:loading ? @"xmark" : @"arrow.clockwise" accessibilityDescription:label]
                             imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium]];
        self.reload.toolTip = label;
    }
    DPPeekRefreshAddress(self.address);
}

- (void)goBack { DPPeekNavigate(self.page, DPPeekBack); }
- (void)goForward { DPPeekNavigate(self.page, DPPeekForward); }
- (void)reloadOrStop {
    DPPeekNavigate(self.page, self.loading ? DPPeekStop : DPPeekReload);
    [self refresh];
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
