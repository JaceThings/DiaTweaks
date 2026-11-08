#import "ProfileEmoji.h"

static char DPRowKey;
static NSString *const DPNoSymbol = @"circle.slash";

static NSArray<NSString *> *DPIconSymbols(void) {
    return @[
        @"house.fill", @"briefcase.fill", @"graduationcap.fill", @"heart.fill", @"star.fill", @"bolt.fill", @"flame.fill", @"leaf.fill",
        @"moon.fill", @"sun.max.fill", @"cloud.fill", @"globe", @"gamecontroller.fill", @"music.note", @"book.fill", @"bookmark.fill",
        @"cart.fill", @"bag.fill", @"creditcard.fill", @"gift.fill", @"hammer.fill", @"paintbrush.fill", @"camera.fill", @"film.fill",
        @"airplane", @"car.fill", @"pawprint.fill", @"cup.and.saucer.fill", @"fork.knife", @"dumbbell.fill", @"person.fill", @"person.2.fill",
        @"building.2.fill", @"terminal.fill", @"chevron.left.forwardslash.chevron.right", @"flask.fill", @"lock.fill", @"shield.fill", @"sparkles",
    ];
}

static NSImage *DPPickerImage(NSString *icon) {
    NSString *name = [icon hasPrefix:DPSymbolPrefix] ? [icon substringFromIndex:DPSymbolPrefix.length] : @"square.dashed";
    return [NSImage imageWithSystemSymbolName:name accessibilityDescription:@"Symbol"];
}

@interface DPEmojiField : NSTextField
@end

@implementation DPEmojiField
- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    if (became) dispatch_async(dispatch_get_main_queue(), ^{ [NSApp orderFrontCharacterPalette:self]; });
    return became;
}
@end

// One profile's icon row: an emoji field and a button that picks a symbol instead. Saving either replaces the other.
@interface DPIconRow : NSObject <NSTextFieldDelegate>
@property(copy) NSString *spaceID;
@property(strong) NSTextField *field;
@property(strong) NSButton *button;
@property(strong) NSPopover *popover;
@end

@implementation DPIconRow
- (void)save:(NSString *)icon {
    DPSaveIcon(self.spaceID, icon);
    self.button.image = DPPickerImage(icon);
}

- (void)controlTextDidChange:(NSNotification *)note {
    __block NSString *last = @"";
    [self.field.stringValue enumerateSubstringsInRange:NSMakeRange(0, self.field.stringValue.length) options:NSStringEnumerationByComposedCharacterSequences
                                            usingBlock:^(NSString *character, NSRange _, NSRange __, BOOL *___) { last = character; }];
    last = [last stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![self.field.stringValue isEqual:last]) self.field.stringValue = last;
    [self save:last.length ? last : nil];
}

- (void)showSymbols:(NSButton *)sender {
    NSString *current = DPSavedIcon(self.spaceID);
    NSGridView *grid = [NSGridView new];
    grid.rowSpacing = grid.columnSpacing = 2;
    NSMutableArray<NSView *> *row = [NSMutableArray array];
    for (NSString *name in [@[ DPNoSymbol ] arrayByAddingObjectsFromArray:DPIconSymbols()]) {
        NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:name];
        if (!image) continue;  // Not in this macOS.
        NSButton *button = [NSButton buttonWithImage:image target:self action:@selector(pickSymbol:)];
        button.bordered = NO;
        button.identifier = name;
        button.toolTip = [name isEqual:DPNoSymbol] ? @"None" : name;
        BOOL chosen = [current isEqual:[DPSymbolPrefix stringByAppendingString:name]] || (!current && [name isEqual:DPNoSymbol]);
        button.contentTintColor = chosen ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
        [NSLayoutConstraint activateConstraints:@[ [button.widthAnchor constraintEqualToConstant:28], [button.heightAnchor constraintEqualToConstant:28] ]];
        [row addObject:button];
        if (row.count < 8) continue;
        [grid addRowWithViews:[row copy]];
        [row removeAllObjects];
    }
    if (row.count) [grid addRowWithViews:row];

    NSView *box = [NSView new];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    [box addSubview:grid];
    [NSLayoutConstraint activateConstraints:@[
        [grid.topAnchor constraintEqualToAnchor:box.topAnchor constant:10], [grid.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-10],
        [grid.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:10], [grid.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-10],
    ]];
    NSViewController *content = [NSViewController new];
    content.view = box;
    content.preferredContentSize = box.fittingSize;
    self.popover = [NSPopover new];
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.contentViewController = content;
    [self.popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}

- (void)pickSymbol:(NSButton *)sender {
    self.field.stringValue = @"";
    [self save:[sender.identifier isEqual:DPNoSymbol] ? nil : [DPSymbolPrefix stringByAppendingString:sender.identifier]];
    [self.popover close];
}
@end

void DPAddEmojiRow(NSViewController *pane) {
    NSView *group = DPFindView(pane.view, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaSettingsFormGroup); });
    NSStackView *rows = (NSStackView *)DPSubview(group, "NSStackView");
    NSTextField *title = (NSTextField *)DPFindView(rows.arrangedSubviews.firstObject, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextField.class]; });
    NSString *spaceID = [DPSwiftValue(pane, @"spaceID") description];
    if (!rows || !title || !spaceID || DPGet(pane, &DPRowKey)) return;

    NSString *icon = DPSavedIcon(spaceID);
    DPIconRow *iconRow = [DPIconRow new];
    iconRow.spaceID = spaceID;
    NSTextField *label = [NSTextField labelWithString:@"Icon"];
    label.font = title.font;
    label.textColor = title.textColor;
    NSTextField *field = iconRow.field = [DPEmojiField textFieldWithString:[icon hasPrefix:DPSymbolPrefix] ? @"" : icon ?: @""];
    field.delegate = iconRow;
    field.alignment = NSTextAlignmentCenter;
    field.bezelStyle = NSTextFieldRoundedBezel;
    field.placeholderString = @"Emoji";
    NSButton *button = iconRow.button = [NSButton buttonWithImage:DPPickerImage(icon) target:iconRow action:@selector(showSymbols:)];
    button.bezelStyle = NSBezelStyleRounded;
    button.toolTip = @"Choose a symbol";
    NSView *row = [NSView new];
    for (NSView *view in @[ label, field, button ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:view];
    }
    NSBox *line = [NSBox new];
    line.boxType = NSBoxSeparator;
    [rows addArrangedSubview:line];
    [rows addArrangedSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:42], [row.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [line.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [field.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.widthAnchor constraintEqualToConstant:64],
        [button.trailingAnchor constraintEqualToAnchor:field.leadingAnchor constant:-8], [button.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    DPSet(pane, &DPRowKey, iconRow);
}
