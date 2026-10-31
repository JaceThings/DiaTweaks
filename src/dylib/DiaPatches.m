#import "DiaPatches.h"

static const CFTimeInterval DPAnimationDuration = 0.25;

static NSUserDefaults *DPDefaults;
static char DPSearchItemKey;

NSView *DPFindView(NSView *root, BOOL (^match)(NSView *)) {
    if (!root || match(root)) return root;
    for (NSView *sub in root.subviews) {
        NSView *found = DPFindView(sub, match);
        if (found) return found;
    }
    return nil;
}

#pragma mark - Patches

// Settings lists the patches in this order.
DPPatch *const DPPatches[] = {
    &DPEdgeToEdge,
    &DPSquareSidebarCorners,
    &DPHideToolbar,
    &DPHideSidebarButton,
    &DPHideChatButton,
    &DPHideChatsButton,
    &DPHideRecentTabsButton,
};
const NSUInteger DPPatchCount = sizeof DPPatches / sizeof *DPPatches;

static void DPAnimate(void) {
    static NSTimer *timer;
    static CFTimeInterval start;
    static CGFloat from[sizeof DPPatches / sizeof *DPPatches];
    start = CACurrentMediaTime();
    for (NSUInteger i = 0; i < DPPatchCount; i++) from[i] = DPPatches[i]->progress;
    if (timer) return;
    timer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *t) {
        CGFloat elapsed = CACurrentMediaTime() - start, omega = 22;
        BOOL done = elapsed >= DPAnimationDuration * 2;
        CGFloat eased = done ? 1 : 1 - (1 + omega * elapsed) * exp(-omega * elapsed);
        for (NSUInteger i = 0; i < DPPatchCount; i++) DPPatches[i]->progress = from[i] + (DPPatches[i]->on - from[i]) * eased;
        for (NSUInteger i = 0; i < DPPatchCount; i++) if (DPPatches[i]->relayout) DPPatches[i]->relayout();
        if (done) {
            [t invalidate];
            timer = nil;
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

static void DPSetPatch(DPPatch *patch, BOOL on) {
    if (patch->on == on) return;
    patch->on = on;
    [DPDefaults setBool:on forKey:patch->key];
    if (patch->apply) patch->apply(patch);
    else DPAnimate();
}

#pragma mark - Settings pane

@interface DPSolidLabel : NSTextField
@end
@implementation DPSolidLabel
- (BOOL)allowsVibrancy { return NO; }
@end

@interface DPSolidImageView : NSImageView
@end
@implementation DPSolidImageView
- (BOOL)allowsVibrancy { return NO; }
@end

static NSView *DPGroup(NSArray<NSView *> *rows) {
    NSStackView *stack = [NSStackView new];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 0;
    [rows enumerateObjectsUsingBlock:^(NSView *row, NSUInteger i, BOOL *_) {
        if (i > 0) {
            NSBox *line = [NSBox new];
            line.boxType = NSBoxSeparator;
            [stack addArrangedSubview:line];
            [line.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-24].active = YES;
        }
        [stack addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }];
    NSBox *box = [NSBox new];
    box.boxType = NSBoxCustom;
    box.borderWidth = 0;
    box.cornerRadius = 10;
    box.fillColor = [NSColor.labelColor colorWithAlphaComponent:0.04];
    box.contentViewMargins = NSZeroSize;
    box.contentView = stack;
    return box;
}

static NSView *DPRow(NSView *leading, NSView *trailing) {
    NSView *row = [NSView new];
    for (NSView *v in @[leading, trailing]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:v];
    }
    [trailing setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [NSLayoutConstraint activateConstraints:@[
        [leading.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [leading.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [leading.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],
        [trailing.leadingAnchor constraintGreaterThanOrEqualToAnchor:leading.trailingAnchor constant:12],
        [trailing.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [trailing.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

static NSTextField *DPLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    return label;
}

static NSView *DPIconTile(NSString *symbol, NSColor *color) {
    NSView *tile = [NSView new];
    tile.wantsLayer = YES;
    tile.layer.backgroundColor = color.CGColor;
    tile.layer.cornerRadius = 5;
    tile.layer.cornerCurve = kCACornerCurveContinuous;
    NSImageView *glyph = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
    glyph.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightSemibold];
    glyph.contentTintColor = NSColor.whiteColor;
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    [tile addSubview:glyph];
    [NSLayoutConstraint activateConstraints:@[
        [tile.widthAnchor constraintEqualToConstant:20],
        [tile.heightAnchor constraintEqualToConstant:20],
        [glyph.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
    ]];
    return tile;
}

static NSToolbarItemIdentifier const DPSearchItemIdentifier = @"DiaPatchesSearch";

@interface DPFlippedView : NSView
@end
@implementation DPFlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface DPPaneView : NSView <NSSearchFieldDelegate>
@property (nonatomic, strong) NSArray<NSSwitch *> *toggles;
@property (nonatomic, strong) NSArray<NSArray *> *sections;  // header, group, rows
@property (nonatomic, strong) NSMapTable<NSView *, NSString *> *searchText;
@property (nonatomic, strong) NSSearchToolbarItem *searchItem;
@property (nonatomic, strong) NSTextField *noResults, *notice;
@property (nonatomic, strong) NSTextField *status;
@property (nonatomic, strong) NSButton *checkButton;
@property (nonatomic, strong) NSButton *relaunchButton;
- (void)updateRows;
@end

@implementation DPPaneView

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _searchText = [NSMapTable strongToStrongObjectsMapTable];
    NSMutableArray<NSView *> *patchRows = [NSMutableArray new];
    NSMutableArray<NSSwitch *> *toggles = [NSMutableArray new];
    for (NSUInteger i = 0; i < DPPatchCount; i++) {
        DPPatch *patch = DPPatches[i];
        NSStackView *text = [NSStackView stackViewWithViews:@[
            DPLabel(patch->title, 13, NSFontWeightRegular, NSColor.labelColor),
            DPLabel(patch->detail, 11, NSFontWeightRegular, NSColor.secondaryLabelColor),
        ]];
        text.orientation = NSUserInterfaceLayoutOrientationVertical;
        text.alignment = NSLayoutAttributeLeading;
        text.spacing = 2;
        NSStackView *leading = [NSStackView stackViewWithViews:@[DPIconTile(patch->symbol, patch->tint()), text]];
        leading.spacing = 10;
        leading.alignment = NSLayoutAttributeCenterY;
        NSSwitch *toggle = [NSSwitch new];
        toggle.controlSize = NSControlSizeSmall;
        toggle.state = patch->on;
        toggle.tag = i;
        toggle.target = self;
        toggle.action = @selector(toggle:);
        [toggles addObject:toggle];
        NSView *row = DPRow(leading, toggle);
        [_searchText setObject:[NSString stringWithFormat:@"%@ %@", patch->title, patch->detail] forKey:row];
        [patchRows addObject:row];
    }
    _toggles = toggles;

    _status = DPLabel(@"", 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
    _checkButton = [NSButton buttonWithTitle:@"Check for Updates" target:self action:@selector(checkForUpdates:)];
    _relaunchButton = [NSButton buttonWithTitle:@"Relaunch to Update" target:self action:@selector(relaunchToUpdate:)];
    _relaunchButton.bezelColor = NSColor.controlAccentColor;
    _relaunchButton.hidden = YES;
    NSView *updateRow = DPRow(_status, [NSStackView stackViewWithViews:@[_relaunchButton, _checkButton]]);
    NSView *restoreRow = DPRow(DPLabel(@"Restore the original Dia without patches.", 13, NSFontWeightRegular, NSColor.labelColor),
                               [NSButton buttonWithTitle:@"Restore…" target:self action:@selector(restore:)]);
    [_searchText setObject:@"Check for updates version" forKey:updateRow];
    [_searchText setObject:@"Restore the original Dia without patches uninstall" forKey:restoreRow];

    _searchItem = [[NSSearchToolbarItem alloc] initWithItemIdentifier:DPSearchItemIdentifier];
    _searchItem.searchField.delegate = self;
    _noResults = DPLabel(@"No results", 13, NSFontWeightRegular, NSColor.secondaryLabelColor);
    _notice = DPLabel(@"DiaPatches is unofficial and not affiliated with The Browser Company.", 11, NSFontWeightRegular, NSColor.tertiaryLabelColor);
    NSMutableArray<NSView *> *views = [NSMutableArray new];
    NSMutableArray<NSArray *> *sections = [NSMutableArray new];
    for (NSArray *section in @[@[@"Interface", patchRows], @[@"Updates", @[updateRow, restoreRow]]]) {
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

    // Dia's Settings window doesn't grow, so the pane scrolls below the window's title.
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
    [self updateRows];
    return self;
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

- (BOOL)matches:(NSView *)row words:(NSArray<NSString *> *)words {
    NSString *text = [self.searchText objectForKey:row];
    for (NSString *word in words) if (word.length && ![text localizedStandardContainsString:word]) return NO;
    return YES;
}

- (void)updateRows {
    NSString *query = self.searchItem.searchField.stringValue;
    NSArray<NSString *> *words = [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    BOOL searching = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length > 0;
    NSMutableSet<NSView *> *unavailable = [NSMutableSet set];
    for (NSSwitch *toggle in self.toggles) {
        DPPatch *patch = DPPatches[toggle.tag];
        if (patch->disabledBy) toggle.enabled = !patch->disabledBy->on;
        if (patch->requires && !patch->requires->on) [unavailable addObject:toggle.superview];
    }
    BOOL anything = NO;
    for (NSArray *section in self.sections) {
        BOOL any = NO;
        for (NSView *row in section[2]) {
            BOOL visible = ![unavailable containsObject:row] && [self matches:row words:words];
            NSArray<NSView *> *arranged = ((NSStackView *)row.superview).arrangedSubviews;
            NSUInteger index = [arranged indexOfObject:row];
            row.hidden = !visible;
            if (index > 0) arranged[index - 1].hidden = !visible || !any;
            any |= visible;
        }
        for (NSView *view in @[section[0], section[1]]) view.hidden = !any;
        anything |= any;
    }
    self.noResults.hidden = anything;
    self.notice.hidden = searching;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateRows];
}

- (void)toggle:(NSSwitch *)sender {
    DPSetPatch(DPPatches[sender.tag], sender.state == NSControlStateValueOn);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.allowsImplicitAnimation = YES;
        [self updateRows];
        [self layoutSubtreeIfNeeded];
    }];
}

- (void)showStatus:(NSDictionary *)status {
    NSString *running = [NSString stringWithFormat:@"Dia %@ (%@)",
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    id staged = status[@"staged"];
    BOOL ready = [staged isKindOfClass:NSString.class];
    self.status.stringValue = !status ? [running stringByAppendingString:@" · couldn’t check for updates"]
                            : ready   ? [NSString stringWithFormat:@"Dia %@ installs when you quit", staged]
                                      : [running stringByAppendingString:@" · up to date"];
    self.relaunchButton.hidden = !ready;
    self.checkButton.enabled = YES;
}

- (void)checkForUpdates:(NSButton *)sender {
    sender.enabled = NO;
    self.status.stringValue = @"Checking for updates…";
    __weak DPPaneView *weakSelf = self;
    DPCheckForUpdates(^(NSDictionary *status) { [weakSelf showStatus:status]; });
}

- (void)refresh {
    __weak DPPaneView *weakSelf = self;
    DPRunCLI(@[@"status", @"--json"], ^(NSString *output) {
        id status = output ? [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
        [weakSelf showStatus:[status isKindOfClass:NSDictionary.class] ? status : nil];
    });
}

- (void)relaunchToUpdate:(id)sender {
    DPHandOffAndQuit(@"apply");
}

- (void)restore:(id)sender {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Restore the original Dia?";
    alert.informativeText = @"Dia will relaunch without patches, and its own updater takes over again. Run the installer to patch it again later.";
    [alert addButtonWithTitle:@"Restore and Relaunch"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPHandOffAndQuit(@"uninstall");
    }];
}
@end

@interface DPSidebarRow : NSControl
@property (nonatomic) BOOL selected;
@property (nonatomic, strong) NSImageView *icon;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic) NSRect iconFrame, labelFrame, pillFrame;
@property (nonatomic, strong) NSFont *labelFont;
@property (nonatomic) CGFloat pillRadius;
@end

@implementation DPSidebarRow {
    NSVisualEffectView *_selection;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _selection = [NSVisualEffectView new];
    _selection.material = NSVisualEffectMaterialSelection;
    _selection.state = NSVisualEffectStateFollowsWindowActiveState;
    _selection.wantsLayer = YES;
    _selection.hidden = YES;
    _icon = [DPSolidImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"wand.and.stars" accessibilityDescription:nil]];
    _label = [DPSolidLabel labelWithString:@"Patches"];
    for (NSView *v in @[_selection, _icon, _label]) [self addSubview:v];
    self.accessibilityRole = NSAccessibilityButtonRole;
    self.accessibilityLabel = @"Patches";
    return self;
}

- (BOOL)allowsVibrancy { return NO; }
- (BOOL)isFlipped { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSNotificationName name in @[NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification]) {
        [center removeObserver:self name:name object:nil];
        if (self.window) [center addObserver:self selector:@selector(redraw) name:name object:self.window];
    }
}

- (void)redraw { self.needsDisplay = YES; }

// Dia's sidebar labels get their dark ink from vibrancy, which this row can't get outside Dia's table, so it draws solid text in the plain appearance.
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.label.appearance = [NSAppearance appearanceNamed:[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]]];
}

- (void)layout {
    [super layout];
    _selection.frame = self.pillFrame;
    _selection.layer.cornerRadius = self.pillRadius;
    _selection.layer.masksToBounds = YES;
    self.icon.frame = self.iconFrame;
    [self.label sizeToFit];
    NSRect labelFrame = self.labelFrame;
    labelFrame.size.width = MAX(labelFrame.size.width, NSWidth(self.label.frame));
    self.label.frame = labelFrame;
}

- (void)setSelected:(BOOL)selected { _selected = selected; [self redraw]; }

- (void)updateLayer {
    BOOL key = self.window.isKeyWindow, emphasized = self.selected && key;
    _selection.hidden = !self.selected;
    _selection.emphasized = emphasized;
    self.label.textColor = emphasized ? NSColor.alternateSelectedControlTextColor : NSColor.textColor;
    NSFont *font = self.labelFont ?: self.label.font;
    NSFont *face = self.selected ? [NSFont systemFontOfSize:font.pointSize weight:NSFontWeightSemibold] : font;
    if (![self.label.font isEqual:face]) {
        self.label.font = face;
        self.needsLayout = YES;
    }
    self.icon.contentTintColor = emphasized ? NSColor.alternateSelectedControlTextColor : key ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor;
}
@end

static NSString *const DPSettingsControllerClass = @"_TtC11Preferences38SidebarPreferencesWindowViewController";

@interface DPSettings : NSObject
@property (nonatomic, weak) NSWindow *window;
@property (nonatomic, weak) NSView *sidebar, *detail;
@property (nonatomic, weak) NSTableView *table;
@property (nonatomic, weak) NSTextField *title;
@property (nonatomic) NSInteger deselectedIndex;
@property (nonatomic, copy) NSString *originalTitle;
@property (nonatomic, strong) DPSidebarRow *row;
@property (nonatomic, strong) DPPaneView *pane;
@property (nonatomic, strong) id monitor;
@end

@implementation DPSettings

+ (void)attachTo:(NSWindow *)window {
    static NSMapTable<NSWindow *, DPSettings *> *attached;
    attached = attached ?: [NSMapTable weakToStrongObjectsMapTable];
    DPSettings *settings = [attached objectForKey:window];
    if (settings) return [settings reposition];
    settings = [DPSettings new];
    if ([settings attachTo:window]) [attached setObject:settings forKey:window];
}

- (BOOL)attachTo:(NSWindow *)window {
    NSSplitViewController *split = (NSSplitViewController *)window.contentViewController;
    if (split.splitViewItems.count < 2) return NO;
    NSView *sidebar = split.splitViewItems.firstObject.viewController.view;
    NSTableView *table = (NSTableView *)DPFindView(sidebar, ^BOOL(NSView *v) { return [v isKindOfClass:NSTableView.class]; });
    if (table.numberOfRows == 0) return NO;

    self.window = window;
    self.sidebar = sidebar;
    self.detail = split.splitViewItems.lastObject.viewController.view;
    self.table = table;
    self.row = [DPSidebarRow new];
    [sidebar addSubview:self.row];
    [self reposition];
    for (NSView *v in @[table, sidebar]) {
        v.postsFrameChangedNotifications = YES;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reposition) name:NSViewFrameDidChangeNotification object:v];
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(diaSelectionChanged) name:NSTableViewSelectionDidChangeNotification object:table];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keepDiaRowDeselected) name:NSWindowDidBecomeKeyNotification object:window];

    // Dia's sidebar handles clicks above the table view, so the row's clicks are consumed before it selects a row.
    __weak DPSettings *weakSelf = self;
    NSEventMask mask = NSEventMaskLeftMouseDown | NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp;
    self.monitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
        DPSettings *me = weakSelf;
        if (!me || event.window != me.window) return event;
        NSView *hit = [me.window.contentView.superview hitTest:event.locationInWindow];
        if ([hit isDescendantOf:me.row]) {
            if (event.type == NSEventTypeLeftMouseDown) {
                [NSApp activate];
                [me.window makeKeyAndOrderFront:nil];
                [me showPane];
            }
            return nil;
        }
        if (!me.pane.superview || [hit isDescendantOf:me.pane]) return event;
        if ([hit isDescendantOf:me.detail]) return nil;
        BOOL onDiaRow = [me.table rowAtPoint:[me.table convertPoint:event.locationInWindow fromView:nil]] >= 0;
        if (event.type == NSEventTypeLeftMouseDown && onDiaRow) [me hidePane];
        return event;
    }];
    return YES;
}

- (void)dealloc {
    [NSEvent removeMonitor:_monitor];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)reposition {
    NSTableView *table = self.table;
    NSInteger count = table.numberOfRows;
    if (count < 2 || !self.sidebar) return;
    NSRect last = [self.sidebar convertRect:[table rectOfRow:count - 1] fromView:table];
    NSRect previous = [self.sidebar convertRect:[table rectOfRow:count - 2] fromView:table];
    self.row.frame = NSOffsetRect(last, 0, NSMinY(last) - NSMinY(previous));

    NSTableRowView *rowView = [table rowViewAtRow:count - 1 makeIfNecessary:NO];
    NSTableCellView *cell = [table viewAtColumn:0 row:count - 1 makeIfNecessary:NO];
    if (!rowView || !cell) return;
    NSRect (^inRow)(NSView *) = ^NSRect(NSView *v) {
        NSRect r = [rowView convertRect:v.bounds fromView:v];
        if (!rowView.isFlipped) r.origin.y = NSHeight(rowView.bounds) - NSMaxY(r);
        return r;
    };
    self.row.iconFrame = inRow(cell.imageView);
    self.row.labelFrame = inRow(cell.textField);
    NSInteger plain = table.selectedRow == count - 1 ? 0 : count - 1;
    self.row.labelFont = [[table viewAtColumn:0 row:plain makeIfNecessary:NO] textField].font ?: self.row.labelFont;
    self.row.icon.symbolConfiguration = cell.imageView.image.symbolConfiguration;

    NSTableRowView *selected = table.selectedRow >= 0 ? [table rowViewAtRow:table.selectedRow makeIfNecessary:NO] : nil;
    NSVisualEffectView *pill = (NSVisualEffectView *)DPFindView(selected, ^BOOL(NSView *v) { return [v isKindOfClass:NSVisualEffectView.class]; });
    if (selected && pill.superview == selected) {
        NSRect r = pill.frame;
        if (!selected.isFlipped) r.origin.y = NSHeight(selected.bounds) - NSMaxY(r);
        self.row.pillFrame = r;
        self.row.pillRadius = pill.maskImage.capInsets.top ?: pill.layer.cornerRadius;
    } else if (NSIsEmptyRect(self.row.pillFrame)) {
        self.row.pillFrame = NSInsetRect(rowView.bounds, 10, 0);
    }
    if (self.row.pillRadius <= 0) self.row.pillRadius = 6;
    self.row.needsLayout = YES;
}

- (void)showPane {
    if (self.pane.superview || !self.detail) return;
    self.pane = self.pane ?: [[DPPaneView alloc] initWithFrame:self.detail.bounds];
    self.pane.frame = self.detail.bounds;
    self.pane.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.detail addSubview:self.pane positioned:NSWindowAbove relativeTo:nil];
    [self.pane refresh];
    NSToolbar *toolbar = self.window.toolbar;
    if (toolbar && ![toolbar.items containsObject:self.pane.searchItem]) {
        objc_setAssociatedObject(toolbar, &DPSearchItemKey, self.pane.searchItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [toolbar insertItemWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier atIndex:toolbar.items.count];
        [toolbar insertItemWithItemIdentifier:DPSearchItemIdentifier atIndex:toolbar.items.count];
    }

    NSInteger selected = self.table.selectedRow;
    if (selected < 0) return;
    NSString *name = [[self.table viewAtColumn:0 row:selected makeIfNecessary:NO] textField].stringValue;
    NSView *content = self.window.contentView;
    self.title = (NSTextField *)DPFindView(content.superview, ^BOOL(NSView *v) {
        return [v isKindOfClass:NSTextField.class] && !v.hiddenOrHasHiddenAncestor && ![v isDescendantOf:content]
            && [((NSTextField *)v).stringValue isEqualToString:name];
    });
    self.originalTitle = self.title.stringValue;
    self.title.stringValue = @"Patches";
    self.deselectedIndex = selected;
    [self.table rowViewAtRow:selected makeIfNecessary:NO].selected = NO;
    self.row.selected = YES;
}

- (void)keepDiaRowDeselected {
    if (!self.pane.superview) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.pane.superview) return;
        [self.detail addSubview:self.pane positioned:NSWindowAbove relativeTo:nil];
        [self.table rowViewAtRow:self.deselectedIndex makeIfNecessary:NO].selected = NO;
        self.row.selected = YES;
    });
}

- (void)diaSelectionChanged {
    NSInteger selected = self.table.selectedRow;
    if (self.pane.superview && selected >= 0 && selected != self.deselectedIndex) [self hidePane];
    else [self keepDiaRowDeselected];
}

- (void)hidePane {
    [self.pane removeFromSuperview];
    NSToolbar *toolbar = self.window.toolbar;
    NSUInteger index = [toolbar.items indexOfObject:self.pane.searchItem];
    if (index != NSNotFound) {
        [toolbar removeItemAtIndex:index];
        if (index > 0 && [toolbar.items[index - 1].itemIdentifier isEqualToString:NSToolbarFlexibleSpaceItemIdentifier]) [toolbar removeItemAtIndex:index - 1];
    }
    self.pane.searchItem.searchField.stringValue = @"";
    [self.pane updateRows];
    if ([self.title.stringValue isEqualToString:@"Patches"]) self.title.stringValue = self.originalTitle;
    if (self.table.selectedRow == self.deselectedIndex) [self.table rowViewAtRow:self.deselectedIndex makeIfNecessary:NO].selected = YES;
    self.row.selected = NO;
}
@end

static NSToolbarItem *DPSettings_toolbarItem(id self, SEL _cmd, NSToolbar *toolbar, NSToolbarItemIdentifier identifier, BOOL willInsert) {
    if ([identifier isEqualToString:DPSearchItemIdentifier]) return objc_getAssociatedObject(toolbar, &DPSearchItemKey);
    return DPCallOriginal(NSToolbarItem *(*)(id, SEL, NSToolbar *, NSToolbarItemIdentifier, BOOL), self, _cmd, toolbar, identifier, willInsert);
}

static void DPSettings_viewDidAppear(NSViewController *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    NSWindow *window = self.view.window;
    dispatch_async(dispatch_get_main_queue(), ^{ if (window) [DPSettings attachTo:window]; });
}

#pragma mark - Bootstrap

__attribute__((constructor)) static void DPInit(void) {
    DPDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    for (NSUInteger i = 0; i < DPPatchCount; i++) {
        DPPatch *patch = DPPatches[i];
        id value = [DPDefaults objectForKey:patch->key];
        patch->on = value ? [value boolValue] : patch->defaultOn;
        patch->progress = patch->on;
    }

    for (NSUInteger i = 0; i < DPPatchCount; i++) if (DPPatches[i]->install) DPPatches[i]->install();
    DPInstallButtons();
    DPHook(NSClassFromString(DPSettingsControllerClass), @selector(viewDidAppear), (IMP)DPSettings_viewDidAppear);
    DPHook(NSClassFromString(DPSettingsControllerClass), @selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:), (IMP)DPSettings_toolbarItem);

    DPInstallUpdates();
}
