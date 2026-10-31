#import "Settings.h"

NSToolbarItemIdentifier const DPSearchItemIdentifier = @"DiaPatchesSearch";

static NSView *DPPatchRow(DPPatch *patch, NSSwitch *toggle) {
    NSStackView *text = [NSStackView stackViewWithViews:@[
        DPLabel(patch->title, 13, NSFontWeightRegular, NSColor.labelColor),
        DPLabel(patch->unavailable ? @"Unavailable on this Dia version." : patch->detail, 11, NSFontWeightRegular, NSColor.secondaryLabelColor),
    ]];
    text.orientation = NSUserInterfaceLayoutOrientationVertical;
    text.alignment = NSLayoutAttributeLeading;
    text.spacing = 2;
    NSStackView *leading = [NSStackView stackViewWithViews:@[DPIconTile(patch->symbol, [NSColor valueForKey:patch->tint]), text]];
    leading.spacing = 10;
    leading.alignment = NSLayoutAttributeCenterY;
    toggle.controlSize = NSControlSizeSmall;
    return DPRow(leading, toggle);
}

@implementation DPPaneView

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _searchText = [NSMapTable strongToStrongObjectsMapTable];
    NSMutableArray<NSView *> *patchRows = [NSMutableArray new];
    NSMutableArray<NSSwitch *> *toggles = [NSMutableArray new];
    for (NSUInteger i = 0; i < DPPatchCount; i++) {
        NSSwitch *toggle = [NSSwitch new];
        toggle.tag = i;
        toggle.target = self;
        toggle.action = @selector(toggle:);
        [toggles addObject:toggle];
        NSView *row = DPPatchRow(DPPatches[i], toggle);
        [_searchText setObject:[NSString stringWithFormat:@"%@ %@", DPPatches[i]->title, DPPatches[i]->detail] forKey:row];
        [patchRows addObject:row];
    }
    _toggles = toggles;
    NSMutableArray<NSArray *> *groups = [NSMutableArray arrayWithArray:@[@[@"Interface", patchRows], @[@"Updates", [self makeUpdateRows]]]];
    if (DPSafeMode) [groups insertObject:@[@"Safe Mode", @[[self makeSafeModeRow]]] atIndex:0];

    _searchItem = [[NSSearchToolbarItem alloc] initWithItemIdentifier:DPSearchItemIdentifier];
    _searchItem.searchField.delegate = self;
    _noResults = DPLabel(@"No results", 13, NSFontWeightRegular, NSColor.secondaryLabelColor);
    _notice = DPLabel(@"DiaPatches is unofficial and not affiliated with The Browser Company.", 11, NSFontWeightRegular, NSColor.tertiaryLabelColor);
    NSMutableArray<NSView *> *views = [NSMutableArray new];
    NSMutableArray<NSArray *> *sections = [NSMutableArray new];
    for (NSArray *section in groups) {
        NSTextField *header = DPLabel(section[0], 12, NSFontWeightSemibold, NSColor.secondaryLabelColor);
        NSView *group = DPGroup(section[1]);
        [views addObjectsFromArray:@[header, group]];
        [sections addObject:@[header, group, section[1]]];
    }
    [views addObjectsFromArray:@[_noResults, _notice]];
    _sections = sections;

    NSStackView *content = [NSStackView stackViewWithViews:views];
    content.orientation = NSUserInterfaceLayoutOrientationVertical;
    content.alignment = NSLayoutAttributeLeading;
    content.spacing = 8;
    for (NSView *v in content.arrangedSubviews) [v.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    [self addScrollingContent:content];
    [self updateRows];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(patchesDidChange:) name:DPPatchesDidChangeNotification object:nil];
    return self;
}

// Dia's Settings window doesn't grow, so the pane scrolls below the window's title.
- (void)addScrollingContent:(NSView *)content {
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
