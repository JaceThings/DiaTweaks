#import "Settings.h"

NSToolbarItemIdentifier const DPSearchItemIdentifier = @"DiaPatchesSearch";

// The overview, and the page of whatever was clicked on it, which replaces it like System Settings.
@implementation DPPaneView {
    NSScrollView *_overviewScroll, *_pageScroll;
    DPPageView *_page;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.wantsLayer = YES;
    _searchItem = [[NSSearchToolbarItem alloc] initWithItemIdentifier:DPSearchItemIdentifier];
    _searchItem.searchField.delegate = self;
    _searchItem.preferredWidthForSearchField = 200;  // Two thirds of the width it takes by default.
    _overview = [DPOverviewView new];
    __weak DPPaneView *weakSelf = self;
    _overview.open = ^(DPItem item) { [weakSelf openPage:item]; };
    _overviewScroll = [self scrollFor:_overview];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(patchesDidChange:) name:DPPatchesDidChangeNotification object:nil];
    return self;
}

// Dia's Settings window puts its toolbar over the pane, so the pane scrolls below the window's title.
- (NSScrollView *)scrollFor:(NSView *)content {
    DPFlippedView *document = [DPFlippedView new];
    NSScrollView *scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.automaticallyAdjustsContentInsets = NO;
    scroll.documentView = document;
    [document addSubview:content];
    [self addSubview:scroll];
    for (NSView *v in @[content, document, scroll]) v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *fill = [content.widthAnchor constraintEqualToAnchor:document.widthAnchor constant:-48];
    fill.priority = NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.topAnchor constant:52],
        [scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [content.topAnchor constraintEqualToAnchor:document.topAnchor constant:20],
        [content.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-20],
        [content.centerXAnchor constraintEqualToAnchor:document.centerXAnchor],
        [content.widthAnchor constraintLessThanOrEqualToConstant:560],
        fill,
    ]];
    return scroll;
}

- (void)openPage:(DPItem)item {
    _page = [[DPPageView alloc] initWithItem:item];
    _pageScroll = [self scrollFor:_page];
    _overviewScroll.hidden = YES;
    if (self.titleChanged) self.titleChanged(item.title, YES);
}

- (BOOL)showsPage { return _page != nil; }

- (void)goBack {
    if (!_page) return;
    [_pageScroll removeFromSuperview];
    _pageScroll = nil;
    _page = nil;
    _overviewScroll.hidden = NO;
    if (self.titleChanged) self.titleChanged(@"Patches", NO);
}

- (void)reset {
    [_pageScroll removeFromSuperview];
    _pageScroll = nil;
    _page = nil;
    _overviewScroll.hidden = NO;
    self.searchItem.searchField.stringValue = @"";
    [self.overview updateWithQuery:@""];
}

// Searching looks through the overview, so typing on a page goes back to it.
- (void)controlTextDidChange:(NSNotification *)notification {
    NSString *query = self.searchItem.searchField.stringValue;
    if (_page && query.length) [self goBack];
    [self.overview updateWithQuery:query];
}

- (void)patchesDidChange:(NSNotification *)notification {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.allowsImplicitAnimation = YES;
        [self.overview updateWithQuery:self.searchItem.searchField.stringValue];
        [self->_page update];
        [self layoutSubtreeIfNeeded];
    }];
}

- (BOOL)isFlipped { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer { self.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor; }

// Unhandled events would reach Dia's pane underneath via the responder chain.
- (void)mouseDown:(NSEvent *)event {}
- (void)mouseDragged:(NSEvent *)event {}
- (void)mouseUp:(NSEvent *)event {}
- (void)rightMouseDown:(NSEvent *)event {}
- (void)rightMouseUp:(NSEvent *)event {}
- (void)otherMouseDown:(NSEvent *)event {}
- (void)otherMouseUp:(NSEvent *)event {}
- (void)scrollWheel:(NSEvent *)event {}
- (NSMenu *)menuForEvent:(NSEvent *)event { return nil; }
@end
