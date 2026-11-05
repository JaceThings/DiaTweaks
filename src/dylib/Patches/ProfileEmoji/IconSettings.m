#import "ProfileIcons.h"

@interface DPEmojiField : NSTextField
@end
@implementation DPEmojiField
- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    if (became) dispatch_async(dispatch_get_main_queue(), ^{ [NSApp orderFrontCharacterPalette:self]; });
    return became;
}
@end

@interface DPProfileIconRow : NSView <NSTextFieldDelegate>
@property(copy) NSString *spaceID;
@property(strong) DPEmojiField *field;
@property(strong) NSButton *symbolButton, *resetButton;
@property(strong) NSBox *separator;
@property(strong) NSPopover *popover;
- (void)refresh;
@end

@implementation DPProfileIconRow
- (void)controlTextDidChange:(NSNotification *)note {
    __block NSString *last = @"";
    [self.field.stringValue enumerateSubstringsInRange:NSMakeRange(0, self.field.stringValue.length) options:NSStringEnumerationByComposedCharacterSequences
        usingBlock:^(NSString *character, NSRange _, NSRange __, BOOL *___) { last = character; }];
    last = [last stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.field.stringValue = last;
    DPStoreProfileIcon(self.spaceID, last, nil);
}

- (void)symbol:(NSButton *)sender {
    DPProfileIconPicker *picker = [DPProfileIconPicker new];
    picker.selectedName = DPProfileSymbolName(self.spaceID);
    __weak DPProfileIconRow *weakSelf = self;
    picker.selection = ^(NSString *name) {
        DPProfileIconRow *row = weakSelf;
        if (!row || !DPProfileEmoji.on) return;
        DPStoreProfileIcon(row.spaceID, DPProfileEmojiValue(row.spaceID), name);
        [row.popover close];
    };
    [self.popover close];
    self.popover = [NSPopover new];
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.contentViewController = picker;
    [self.popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMinY];
}

- (void)resetIcon:(id)sender { DPStoreProfileIcon(self.spaceID, nil, nil); }

- (void)refresh {
    self.field.stringValue = DPProfileEmojiValue(self.spaceID) ?: @"";
    NSString *name = DPProfileSymbolName(self.spaceID);
    self.symbolButton.image = DPProfileSymbolImage(name, 13);
    self.symbolButton.toolTip = DPProfilePreferredSymbolName(name) ?: name;
    self.resetButton.enabled = name.length || self.field.stringValue.length;
}
@end

static NSHashTable<NSViewController *> *DPProfilePanes;
static char DPRowKey;

static void DPAddIconRow(NSViewController *pane) {
    NSView *group = DPFindView(pane.view, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaSettingsFormGroup); });
    NSStackView *rows = (NSStackView *)DPSubview(group, "NSStackView");
    NSTextField *title = (NSTextField *)DPFindView(rows.arrangedSubviews.firstObject, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextField.class]; });
    NSString *spaceID = [DPSwiftValue(pane, @"spaceID") description];
    if (!rows || !title || !spaceID) return;
    DPProfileIconRow *row = [DPProfileIconRow new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.spaceID = spaceID;
    NSTextField *label = [NSTextField labelWithString:@"Icon"];
    label.font = title.font;
    label.textColor = title.textColor;
    row.field = [DPEmojiField textFieldWithString:@""];
    row.field.delegate = row;
    row.field.alignment = NSTextAlignmentCenter;
    row.field.bezelStyle = NSTextFieldRoundedBezel;
    row.field.placeholderString = @"Emoji";
    row.field.accessibilityLabel = @"Profile emoji";
    row.field.toolTip = @"Enter an emoji to replace the symbol";
    row.symbolButton = [NSButton buttonWithTitle:@"Symbol" target:row action:@selector(symbol:)];
    row.symbolButton.imagePosition = NSImageLeft;
    row.symbolButton.contentTintColor = NSColor.labelColor;
    row.resetButton = [NSButton buttonWithTitle:@"Reset" target:row action:@selector(resetIcon:)];
    row.resetButton.toolTip = @"Restore the default dot";
    NSStackView *controls = [NSStackView stackViewWithViews:@[ row.field, row.symbolButton, row.resetButton ]];
    controls.spacing = 8;
    for (NSView *view in @[ label, controls ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:view];
    }
    row.separator = [NSBox new];
    row.separator.translatesAutoresizingMaskIntoConstraints = NO;
    row.separator.boxType = NSBoxSeparator;
    [rows addArrangedSubview:row.separator];
    [rows addArrangedSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:42], [row.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [row.separator.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [controls.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [controls.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [controls.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:8],
        [row.field.widthAnchor constraintEqualToConstant:64],
    ]];
    DPSet(pane, &DPRowKey, row);
}

void DPUpdateProfilePanes(void) {
    for (NSViewController *pane in DPProfilePanes) {
        DPProfileIconRow *row = DPGet(pane, &DPRowKey);
        if (!DPProfileEmoji.on && row) {
            [row.popover close];
            NSStackView *rows = (NSStackView *)row.superview;
            [rows removeArrangedSubview:row.separator];
            [row.separator removeFromSuperview];
            [rows removeArrangedSubview:row];
            [row removeFromSuperview];
            DPSet(pane, &DPRowKey, nil);
        }
        if (DPProfileEmoji.on && !DPGet(pane, &DPRowKey)) DPAddIconRow(pane);
        [(DPProfileIconRow *)DPGet(pane, &DPRowKey) refresh];
    }
}

void DPTrackProfilePane(NSViewController *pane) {
    if (!DPProfilePanes) DPProfilePanes = NSHashTable.weakObjectsHashTable;
    [DPProfilePanes addObject:pane];
    DPUpdateProfilePanes();
}
