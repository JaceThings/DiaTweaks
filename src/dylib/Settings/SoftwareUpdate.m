#import "Settings.h"

static NSString *DPPartName(NSString *part) { return [part isEqual:DPDia] ? @"Dia" : @"DiaTweaks"; }

static NSView *DPPartIcon(NSString *part) {
    NSImage *image = [part isEqual:DPDia] ? [NSWorkspace.sharedWorkspace iconForFile:NSBundle.mainBundle.bundlePath]
                                          : [NSImage imageWithSystemSymbolName:@"wand.and.stars" accessibilityDescription:nil];
    NSImageView *icon = [NSImageView imageViewWithImage:image];
    if ([part isEqual:DPTweaks]) {
        icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightSemibold];
        icon.contentTintColor = NSColor.whiteColor;
        icon.wantsLayer = YES;
        icon.layer.backgroundColor = NSColor.systemPurpleColor.CGColor;
        icon.layer.cornerRadius = 7;
        icon.layer.cornerCurve = kCACornerCurveContinuous;
    }
    CGFloat size = [part isEqual:DPDia] ? 36 : 30;
    [icon.widthAnchor constraintEqualToConstant:size].active = YES;
    [icon.heightAnchor constraintEqualToConstant:size].active = YES;
    return icon;
}

static NSTextField *DPLine(NSString *text, CGFloat size, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:size];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

// The first paragraph: Dia's notes go on to list every change, GitHub's to headings and bullets.
static NSString *DPSummary(NSString *notes) {
    for (NSString *line in [notes componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (trimmed.length && ![trimmed hasPrefix:@"#"]) return trimmed;
    }
    return nil;
}

static NSButton *DPButton(NSString *title, id target, SEL action, NSString *part) {
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.identifier = part;
    return button;
}

// Like macOS's Software Update: what's available with its notes, then what's installed and the automatic settings.
@implementation DPSoftwareUpdateView {
    NSString *_shape;
    NSMapTable<NSString *, NSProgressIndicator *> *_bars;
    NSMapTable<NSString *, NSTextField *> *_details;
    NSMutableArray<NSSwitch *> *_automatic;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _bars = [NSMapTable strongToStrongObjectsMapTable];
    _details = [NSMapTable strongToStrongObjectsMapTable];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(sync) name:DPUpdatesDidChangeNotification object:nil];
    DPUpdates *updates = DPUpdates.shared;
    if (!updates.checking && ![updates downloading:DPDia] && ![updates downloading:DPTweaks]) [updates check];
    [self sync];
    return self;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (NSArray<NSString *> *)shown {
    DPUpdates *updates = DPUpdates.shared;
    NSMutableArray *parts = [NSMutableArray new];
    for (NSString *part in @[DPDia, DPTweaks])
        if ([updates available:part] || [updates staged:part] || [updates downloading:part]) [parts addObject:part];
    return parts;
}

- (NSString *)stateOf:(NSString *)part {
    DPUpdates *updates = DPUpdates.shared;
    return [updates downloading:part] ? @"downloading" : [updates staged:part] ? @"staged" : @"available";
}

// Rebuilds only when something other than download progress changed, so buttons don't move under the pointer.
- (void)sync {
    DPUpdates *updates = DPUpdates.shared;
    NSMutableString *shape = [NSMutableString stringWithFormat:@"%d %d", updates.checking, updates.found != nil];
    for (NSString *part in self.shown)
        [shape appendFormat:@" %@:%@:%@:%d", part, [self stateOf:part], updates.found[part][@"latest"], [updates failed:part]];
    for (NSString *key in @[DPAutoCheck, DPAutoDownload, DPAutoInstallDia, DPAutoInstallTweaks]) [shape appendFormat:@"%d", DPAutoUpdate(key)];
    if (![shape isEqual:_shape]) {
        _shape = shape;
        [self rebuild];
    }
    for (NSString *part in _bars) {
        double progress = [updates progress:part];
        NSProgressIndicator *bar = [_bars objectForKey:part];
        bar.indeterminate = progress < 0;
        if (progress < 0) [bar startAnimation:nil];
        else bar.doubleValue = progress;
        [_details objectForKey:part].stringValue = progress < 0 ? @"Preparing…"
            : [NSString stringWithFormat:@"Downloading… %.0f%%", progress * 100];
    }
}

- (void)rebuild {
    for (NSView *view in self.arrangedSubviews) [view removeFromSuperview];
    [_bars removeAllObjects];
    [_details removeAllObjects];
    DPUpdates *updates = DPUpdates.shared;
    NSMutableArray<NSView *> *views = [NSMutableArray new];
    NSArray<NSString *> *shown = self.shown;

    if (updates.checking && !shown.count) {
        NSProgressIndicator *spinner = [NSProgressIndicator new];
        spinner.style = NSProgressIndicatorStyleSpinning;
        spinner.controlSize = NSControlSizeSmall;
        [spinner startAnimation:nil];
        [views addObject:DPGroup(@[DPRow(DPLine(@"Checking for updates…", 13, NSColor.labelColor), spinner)])];
    } else if (!updates.found) {
        [views addObject:DPGroup(@[DPRow(DPLine(@"Couldn’t check for updates", 13, NSColor.labelColor),
                                         [NSButton buttonWithTitle:@"Try Again" target:self action:@selector(checkAgain:)])])];
    } else if (!shown.count) {
        [views addObject:DPGroup(@[DPRow(DPLine(@"Everything is up to date", 13, NSColor.labelColor),
                                         [NSButton buttonWithTitle:@"Check Now" target:self action:@selector(checkAgain:)])])];
    }

    for (NSString *part in shown) {
        if (part != shown.firstObject) {
            NSStackView *header = [NSStackView stackViewWithViews:@[DPLabel(@"Also Available", 12, NSFontWeightSemibold, NSColor.secondaryLabelColor)]];
            [header addView:[NSButton buttonWithTitle:@"Update All" target:self action:@selector(updateAll:)] inGravity:NSStackViewGravityTrailing];
            [views addObject:header];
        }
        [views addObject:[self groupFor:part]];
    }

    NSMutableArray<NSView *> *installed = [NSMutableArray new];
    for (NSString *part in @[DPDia, DPTweaks]) {
        id version = updates.found[part][@"installed"];
        NSString *text = [version isKindOfClass:NSString.class] ? version : [part isEqual:DPDia] ? @"—" : @"Development build";
        [installed addObject:DPRow(DPLine(DPPartName(part), 13, NSColor.labelColor), DPLine(text, 13, NSColor.secondaryLabelColor))];
    }
    [views addObjectsFromArray:@[DPLabel(@"Installed", 12, NSFontWeightSemibold, NSColor.secondaryLabelColor), DPGroup(installed)]];

    NSButton *info = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"info.circle" accessibilityDescription:@"Automatic Updates options"]
                                        target:self action:@selector(showAutomatic:)];
    info.bordered = NO;
    info.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightRegular];
    info.contentTintColor = NSColor.secondaryLabelColor;
    NSStackView *trailing = [NSStackView stackViewWithViews:@[DPLine(self.automaticSummary, 13, NSColor.secondaryLabelColor), info]];
    trailing.spacing = 8;
    [views addObject:DPGroup(@[DPRow(DPLine(@"Automatic Updates", 13, NSColor.labelColor), trailing)])];

    DPFillStack(self, views);
    [self setCustomSpacing:14 afterView:views.firstObject];
}

- (NSView *)groupFor:(NSString *)part {
    DPUpdates *updates = DPUpdates.shared;
    NSDictionary *found = updates.found[part];
    NSString *state = [self stateOf:part];
    BOOL installsOnQuit = DPAutoUpdate([part isEqual:DPDia] ? DPAutoInstallDia : DPAutoInstallTweaks);
    NSString *size = [NSByteCountFormatter stringFromByteCount:[found[@"size"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
    NSTextField *detail = DPLine([state isEqual:@"staged"] ? (installsOnQuit ? @"Installs when you quit" : @"Ready to install")
                                 : [updates failed:part] ? @"Download failed" : size,
                                 11, [updates failed:part] ? NSColor.systemRedColor : NSColor.secondaryLabelColor);
    NSStackView *leading = [NSStackView stackViewWithViews:@[
        DPPartIcon(part),
        DPColumn(@[DPLine([NSString stringWithFormat:@"%@ %@", DPPartName(part), found[@"latest"]], 13, NSColor.labelColor), detail], 2),
    ]];
    leading.spacing = 10;

    NSView *trailing;
    if ([state isEqual:@"downloading"]) {
        NSProgressIndicator *bar = [NSProgressIndicator new];
        bar.style = NSProgressIndicatorStyleBar;
        bar.indeterminate = NO;
        bar.minValue = 0;
        bar.maxValue = 1;
        [bar.widthAnchor constraintEqualToConstant:140].active = YES;
        [_bars setObject:bar forKey:part];
        [_details setObject:detail forKey:part];
        trailing = bar;
    } else if ([state isEqual:@"staged"]) {
        trailing = DPButton(@"Relaunch", self, @selector(relaunch:), part);
    } else {
        trailing = [NSStackView stackViewWithViews:@[DPButton([updates failed:part] ? @"Try Again" : @"Download", self, @selector(download:), part),
                                                     DPButton(@"Update Now", self, @selector(updateNow:), part)]];
    }
    NSMutableArray *rows = [NSMutableArray arrayWithObject:DPRow(leading, trailing)];
    NSString *summary = DPSummary(found[@"notes"]);
    if (summary) {
        NSTextField *text = DPLabel(summary, 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
        text.maximumNumberOfLines = 3;
        text.cell.truncatesLastVisibleLine = YES;
        [rows addObject:DPRow(text, [NSStackView new])];
    }
    return DPGroup(rows);
}

- (NSString *)automaticSummary {
    if (!DPAutoUpdate(DPAutoCheck)) return @"Off";
    if (!DPAutoUpdate(DPAutoDownload)) return @"Check only";
    BOOL dia = DPAutoUpdate(DPAutoInstallDia), tweaks = DPAutoUpdate(DPAutoInstallTweaks);
    return dia && tweaks ? @"On" : dia ? @"Dia only" : tweaks ? @"DiaTweaks only" : @"Download only";
}

- (void)checkAgain:(id)sender { [DPUpdates.shared check]; }
- (void)download:(NSButton *)sender { [DPUpdates.shared download:sender.identifier]; }
- (void)relaunch:(NSButton *)sender { [DPUpdates.shared installAndRelaunch:@[sender.identifier]]; }

- (void)updateNow:(NSButton *)sender {
    NSString *part = sender.identifier;
    [DPUpdates.shared download:part then:^{
        if ([DPUpdates.shared staged:part]) [DPUpdates.shared installAndRelaunch:@[part]];
    }];
}

- (void)updateAll:(id)sender {
    DPUpdates *updates = DPUpdates.shared;
    NSArray<NSString *> *parts = self.shown;
    __block NSUInteger left = parts.count;
    void (^ready)(void) = ^{ if (--left == 0) [updates installAndRelaunch:parts]; };
    for (NSString *part in parts) {
        if ([updates staged:part]) ready();
        else [updates download:part then:ready];
    }
}

#pragma mark Automatic Updates sheet

- (void)showAutomatic:(id)sender {
    NSArray<NSArray<NSString *> *> *options = @[
        @[DPAutoCheck, @"Check for updates"],
        @[DPAutoDownload, @"Download updates when available"],
        @[DPAutoInstallDia, @"Install Dia updates"],
        @[DPAutoInstallTweaks, @"Install DiaTweaks updates"],
    ];
    _automatic = [NSMutableArray new];
    NSMutableArray<NSView *> *rows = [NSMutableArray new];
    for (NSArray<NSString *> *option in options) {
        NSSwitch *toggle = [NSSwitch new];
        toggle.controlSize = NSControlSizeSmall;
        toggle.state = DPAutoUpdate(option[0]);
        toggle.identifier = option[0];
        toggle.accessibilityLabel = option[1];
        toggle.target = self;
        toggle.action = @selector(automaticChanged:);
        [_automatic addObject:toggle];
        [rows addObject:DPRow(DPLine(option[1], 13, NSColor.labelColor), toggle)];
    }
    NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(endAutomatic:)];
    NSButton *done = [NSButton buttonWithTitle:@"Done" target:self action:@selector(endAutomatic:)];
    cancel.keyEquivalent = @"\e";
    done.keyEquivalent = @"\r";
    done.tag = NSModalResponseOK;
    NSStackView *buttons = [NSStackView stackViewWithViews:@[cancel, done]];
    NSStackView *stack = [NSStackView new];
    DPFillStack(stack, @[DPGroup(rows)]);
    [stack addArrangedSubview:buttons];
    stack.alignment = NSLayoutAttributeTrailing;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *content = [NSView new];
    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-20],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [stack.widthAnchor constraintEqualToConstant:400],
    ]];
    [self automaticChanged:nil];

    NSWindow *sheet = [[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
    sheet.contentView = content;
    [self.window beginSheet:sheet completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK) return;
        for (NSSwitch *toggle in self->_automatic) DPSetAutoUpdate(toggle.identifier, toggle.state == NSControlStateValueOn);
        [self sync];
    }];
}

// Each option needs the one above it, the way macOS's do.
- (void)automaticChanged:(id)sender {
    BOOL check = _automatic[0].state == NSControlStateValueOn, download = check && _automatic[1].state == NSControlStateValueOn;
    _automatic[1].enabled = check;
    _automatic[2].enabled = _automatic[3].enabled = download;
}

- (void)endAutomatic:(NSButton *)sender { [self.window endSheet:sender.window returnCode:sender.tag == NSModalResponseOK ? NSModalResponseOK : NSModalResponseCancel]; }
@end
