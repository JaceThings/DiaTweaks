#import "Patches/Boosts/Editor.h"

static const CGFloat DPEditorWidth = 340, DPEditorInset = 14, DPZapListHeight = 180;
static char DPZapKey;     // The zap a row's button shows again.
static char DPHeightKey;  // A row's height, which opens and closes it.

// Monospaced, on the same ground as Settings' groups.
static NSView *DPCodeBox(NSString *text, id<NSTextViewDelegate> delegate, NSTextView **editor) {
    NSScrollView *scroll = [NSTextView scrollableTextView];
    NSTextView *code = scroll.documentView;
    code.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    code.textColor = NSColor.labelColor;
    code.richText = NO;
    code.allowsUndo = YES;
    code.usesFindBar = YES;
    code.automaticQuoteSubstitutionEnabled = code.automaticDashSubstitutionEnabled = code.automaticTextReplacementEnabled = NO;
    code.automaticSpellingCorrectionEnabled = code.continuousSpellCheckingEnabled = code.automaticLinkDetectionEnabled = NO;
    code.textContainerInset = NSMakeSize(6, 8);
    code.drawsBackground = scroll.drawsBackground = NO;
    code.string = text;
    code.delegate = delegate;
    DPFillView *box = [DPFillView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [box addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:box.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:box.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:box.topAnchor], [scroll.bottomAnchor constraintEqualToAnchor:box.bottomAnchor],
        [box.heightAnchor constraintEqualToConstant:110],
    ]];
    *editor = code;
    return box;
}

// "Site’s Own" first, then every family. A saved font that's no longer installed stays listed, so it isn't lost.
static NSPopUpButton *DPFontPicker(NSString *font) {
    NSPopUpButton *picker = [NSPopUpButton new];
    picker.controlSize = NSControlSizeSmall;
    picker.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    [picker addItemWithTitle:@"Site’s Own"];
    picker.lastItem.representedObject = @"";
    [picker.menu addItem:NSMenuItem.separatorItem];
    NSArray *families = NSFontManager.sharedFontManager.availableFontFamilies;
    for (NSString *family in [families containsObject:font] || !font.length ? families : [@[ font ] arrayByAddingObjectsFromArray:families]) {
        [picker addItemWithTitle:family];
        picker.lastItem.representedObject = family;
    }
    [picker selectItemAtIndex:MAX(0, [picker indexOfItemWithRepresentedObject:font])];
    return picker;
}

// A group's line, one pixel thick. NSBox's separator keeps a 5-point frame and draws at its bottom, which left more
// room over each row's text than under it.
@interface DPBoostLine : NSView
@end

@implementation DPBoostLine
- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    return self;
}
- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric, 1 / (self.window.backingScaleFactor ?: 2)); }
- (void)viewDidChangeBackingProperties { [self invalidateIntrinsicContentSize]; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer { self.layer.backgroundColor = NSColor.separatorColor.CGColor; }
@end

@interface DPRowDrawer : NSObject
@property (nonatomic, weak) DPBoostEditor *editor;
@property (nonatomic, strong) NSView *row;
@property (nonatomic, strong) NSLayoutConstraint *height;
@property (nonatomic) CGFloat from, to;
@property (nonatomic) CFTimeInterval start;
@property (nonatomic, copy) void (^done)(void);
@end

@implementation DPRowDrawer
- (void)step:(CADisplayLink *)link {  // The link holds the drawer until it's invalidated.
    if (!self.start) self.start = link.timestamp;
    double t = self.editor.view.window ? MIN((link.timestamp - self.start) / 0.25, 1) : 1;
    double eased = t < 0.5 ? 4 * t * t * t : 1 - pow(2 - 2 * t, 3) / 2;
    self.height.constant = self.from + (self.to - self.from) * eased;
    self.row.alphaValue = self.to > self.from ? eased : 1 - eased;
    NSPopover *popover = self.editor.popover;
    NSSize size = self.editor.view.fittingSize;
    if (!NSEqualSizes(size, popover.contentSize)) {
        popover.animates = NO;
        popover.contentSize = size;
        popover.animates = YES;
    }
    [self.editor.view layoutSubtreeIfNeeded];
    if (t < 1) return;
    [link invalidate];
    if (self.done) self.done();
}
@end

@implementation DPBoostEditor (Layout)

- (NSView *)makeContent:(NSDictionary *)boost {
    self.enabled = [NSSwitch new];
    self.enabled.state = [boost[@"enabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    self.enabled.target = self;
    self.enabled.action = @selector(changed:);
    NSTextField *site = DPBoostLabel(@"");
    site.attributedStringValue = DPBoostTitle(DPBoostSiteName(self.domain), self.domain, NSFontWeightSemibold);
    NSString *domain = self.domain;
    if ([DPFrontDomain() isEqual:domain])
        DPPageSiteName(DPFrontContents(), ^(NSString *name) { site.attributedStringValue = DPBoostTitle(name, domain, NSFontWeightSemibold); });
    NSStackView *heading = [NSStackView stackViewWithViews:@[ DPBoostFavicon(self.domain, 16), site ]];

    NSView *hidden = [self makeZapGroup];
    self.font = DPFontPicker(boost[@"font"]);
    self.font.target = self;
    self.font.action = @selector(changed:);

    NSTextView *css, *js;
    NSView *cssBox = DPCodeBox(boost[@"css"], self, &css), *jsBox = DPCodeBox(boost[@"js"], self, &js);
    self.css = css;
    self.js = js;
    NSTextField *jsHint = DPLabel(@"Runs as each page of the site loads. Reload the page to try a change.", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);

    NSPopUpButton *more = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES];
    more.controlSize = NSControlSizeSmall;
    more.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    [more addItemWithTitle:@"Options"];
    [more.menu addItemWithTitle:@"Import Boost File…" action:@selector(importBoost:) keyEquivalent:@""].target = self;
    [more.menu addItemWithTitle:@"Export Boost File…" action:@selector(exportBoost:) keyEquivalent:@""].target = self;
    [more.menu addItem:NSMenuItem.separatorItem];
    [more.menu addItemWithTitle:@"Delete Boost…" action:@selector(deleteBoost:) keyEquivalent:@""].target = self;
    NSStackView *footer = [NSStackView new];
    [footer addView:more inGravity:NSStackViewGravityTrailing];

    NSStackView *content = [NSStackView new];
    DPFillStack(content, @[
        DPGroup(@[ DPRow(heading, self.enabled) ]), DPHeader(@"Hidden"), hidden,
        DPGroup(@[ DPRow(DPLabel(@"Font", 13, NSFontWeightRegular, NSColor.labelColor), self.font) ]),
        DPHeader(@"CSS"), cssBox, DPHeader(@"JavaScript"), jsBox, jsHint, footer,
    ]);
    [content setCustomSpacing:6 afterView:jsBox];
    NSView *root = [DPFlippedView new];  // Growing, it keeps what's in it where it was from the top, not the bottom, until laid out.
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:DPEditorInset],
        [content.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-DPEditorInset],
        [content.topAnchor constraintEqualToAnchor:root.topAnchor constant:DPEditorInset],
        // The Options button draws its bezel a couple of points inside its frame, so it looks as far from the bottom as from the side.
        [content.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-(DPEditorInset - 2)],  // Stays put while the popover resizes.
        [root.widthAnchor constraintEqualToConstant:DPEditorWidth],
    ]];
    return root;
}

// The Zap row, then what it hid, newest first, each under a line like a group's. The list scrolls past DPZapListHeight,
// so the popover stops growing there.
- (NSView *)makeZapGroup {
    self.zapButton = [NSButton buttonWithTitle:@"" target:self action:@selector(zap:)];
    self.zapButton.controlSize = NSControlSizeSmall;
    self.zapHow = DPBoostLabel(@"");
    NSView *zapRow = DPRow(self.zapHow, self.zapButton);

    self.zapRows = [NSStackView new];
    self.zapRows.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.zapRows.spacing = 0;
    DPFlippedView *list = [DPFlippedView new];
    self.zapRows.translatesAutoresizingMaskIntoConstraints = list.translatesAutoresizingMaskIntoConstraints = NO;
    [list addSubview:self.zapRows];
    self.zapScroll = [NSScrollView new];
    self.zapScroll.drawsBackground = NO;
    self.zapScroll.hasVerticalScroller = YES;
    self.zapScroll.autohidesScrollers = YES;
    self.zapScroll.documentView = list;
    // Just under the rows' own height, or past DPZapListHeight Auto Layout may as well squash the last rows as scroll.
    NSLayoutConstraint *fit = [self.zapScroll.heightAnchor constraintEqualToAnchor:list.heightAnchor];
    fit.priority = NSLayoutPriorityDefaultHigh - 1;
    [NSLayoutConstraint activateConstraints:@[
        [self.zapRows.leadingAnchor constraintEqualToAnchor:list.leadingAnchor], [self.zapRows.trailingAnchor constraintEqualToAnchor:list.trailingAnchor],
        [self.zapRows.topAnchor constraintEqualToAnchor:list.topAnchor], [self.zapRows.bottomAnchor constraintEqualToAnchor:list.bottomAnchor],
        [list.widthAnchor constraintEqualToAnchor:self.zapScroll.contentView.widthAnchor],
        [list.topAnchor constraintEqualToAnchor:self.zapScroll.contentView.topAnchor],
        fit, [self.zapScroll.heightAnchor constraintLessThanOrEqualToConstant:DPZapListHeight],
    ]];
    for (NSDictionary *zap in self.zaps) [self addZapRow:zap animated:NO];
    [self showZapping];

    NSStackView *column = DPColumn(@[ zapRow, self.zapScroll ], 0);
    for (NSView *view in column.arrangedSubviews) [view.widthAnchor constraintEqualToAnchor:column.widthAnchor].active = YES;
    return DPGroup(@[ column ]);
}

- (void)showZapping {
    self.zapButton.title = self.zapping ? @"Done" : @"Zap…";
    self.zapHow.stringValue = self.zapping ? @"Click what you want to hide" : @"Hide part of the page";
}

static CGFloat DPRowHeight(NSView *row) {
    CGFloat height = 0;
    for (NSView *view in row.subviews) height += view.fittingSize.height;
    return height;
}

// A row opens and closes like a drawer: its height goes to or from 0 with what's in it pinned to its top, so nothing in
// it moves while everything under it slides. NSPopover's own resizing runs on its own clock and jolts its top, so the
// height, the fade and the popover's size all step here together, each frame, the popover's size taken at once.
- (void)open:(BOOL)open row:(NSView *)row done:(void (^)(void))done {
    DPRowDrawer *drawer = [DPRowDrawer new];
    drawer.editor = self;
    drawer.row = row;
    drawer.height = DPGet(row, &DPHeightKey);
    drawer.from = drawer.height.constant;
    drawer.to = open ? DPRowHeight(row) : 0;
    drawer.done = done;
    [[self.view displayLinkWithTarget:drawer selector:@selector(step:)] addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

// One thing hidden, under a line like a group's.
- (void)addZapRow:(NSDictionary *)zap animated:(BOOL)animated {
    NSButton *show = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"minus.circle" accessibilityDescription:@"Show It Again"] target:self action:@selector(unzap:)];
    show.bordered = NO;
    show.contentTintColor = NSColor.secondaryLabelColor;
    DPSet(show, &DPZapKey, zap);
    NSView *content = DPRow(DPBoostLabel(zap[@"label"]), show);
    NSView *line = [DPBoostLine new];
    NSView *row = [NSView new];
    row.wantsLayer = YES;
    row.layer.masksToBounds = YES;
    for (NSView *view in @[ line, content ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:view];
    }
    NSLayoutConstraint *height = [row.heightAnchor constraintEqualToConstant:animated ? 0 : DPRowHeight(row)];
    [NSLayoutConstraint activateConstraints:@[
        [line.topAnchor constraintEqualToAnchor:row.topAnchor],
        [line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12], [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [content.topAnchor constraintEqualToAnchor:line.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        height,
    ]];
    DPSet(row, &DPHeightKey, height);
    [self.zapRows insertArrangedSubview:row atIndex:0];
    [row.widthAnchor constraintEqualToAnchor:self.zapRows.widthAnchor].active = YES;
    if (!animated) return;
    row.alphaValue = 0;
    [self open:YES row:row done:nil];
}

- (void)unzap:(NSButton *)sender {
    NSUInteger index = [self.zaps indexOfObjectIdenticalTo:DPGet(sender, &DPZapKey)];
    if (index == NSNotFound) return;
    [self.zaps removeObjectAtIndex:index];
    [self save];
    NSView *row = sender.superview.superview;
    sender.enabled = NO;
    [self open:NO row:row done:^{ [row removeFromSuperview]; }];
}

@end
