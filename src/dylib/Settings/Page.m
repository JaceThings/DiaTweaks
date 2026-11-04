#import "Settings.h"

static char DPChoicePatchKey;  // The patch a picker chooses for, when it's an option's.

@implementation DPPageView {
    DPPatch *_patch;
    NSMutableArray<DPPatchSwitch *> *_switches;
    NSTextField *_note;
    NSArray<NSView *> *_rows;
    NSMutableArray<NSView *> *_optionChoices;  // Shown only while their option is on.
}

- (instancetype)initWithPatch:(DPPatch *)patch {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    _patch = patch;
    _switches = [NSMutableArray new];
    _optionChoices = [NSMutableArray new];
    _note = DPLabel(@"", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);

    DPPreviewView *preview = [[DPPreviewView alloc] initWithKey:patch->key];
    [preview.heightAnchor constraintEqualToAnchor:preview.widthAnchor multiplier:10.0 / 16].active = YES;
    NSMutableArray<NSView *> *headingText = [@[
        DPLabel(patch->title, 13, NSFontWeightSemibold, NSColor.labelColor),
        DPLabel(patch->detail, 11, NSFontWeightRegular, NSColor.secondaryLabelColor),
    ] mutableCopy];
    if (patch->hint) {
        NSView *gap = [NSView new];  // A little space between the detail and the tip.
        [gap.heightAnchor constraintEqualToConstant:5].active = YES;
        [headingText addObjectsFromArray:@[gap, DPLabel(patch->hint, 11, NSFontWeightRegular, NSColor.secondaryLabelColor)]];
    }
    [headingText addObject:_note];
    NSStackView *heading = [NSStackView stackViewWithViews:@[
        DPIconTile(patch->symbol, [NSColor valueForKey:patch->tint]),
        DPColumn(headingText, 2),
    ]];
    heading.spacing = 10;
    heading.alignment = NSLayoutAttributeTop;
    NSMutableArray<NSView *> *views = [NSMutableArray arrayWithObjects:preview, DPGroup(@[DPRow(heading, [self switchFor:patch])]), nil];

    // Options sit under their own section's heading, like the tweaks on the main page, and ones this Dia can't use go last.
    NSString *const unavailable = @"Not Available in This Version";
    NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithObject:@"Options"];
    NSMutableDictionary<NSString *, NSMutableArray<NSView *> *> *groups = [NSMutableDictionary dictionaryWithObject:[NSMutableArray new] forKey:@"Options"];
    DPForEachOption(patch, ^(DPPatch *option) {
        NSString *title = option->unavailable ? unavailable : option->section ?: @"Options";
        if (!groups[title]) {
            [titles addObject:title];
            groups[title] = [NSMutableArray new];
        }
        NSMutableArray<NSView *> *lines = [NSMutableArray arrayWithObjects:DPLabel(option->title, 13, NSFontWeightRegular, NSColor.labelColor),
                                           DPLabel(option->detail, 11, NSFontWeightRegular, NSColor.secondaryLabelColor), nil];
        if (option->unavailable) [lines addObject:DPLabel(DPWhyDisabled(option), 11, NSFontWeightRegular, NSColor.secondaryLabelColor)];
        NSView *text = DPColumn(lines, 2);
        [groups[title] addObject:DPRow(text, [self switchFor:option])];
        // An option's own choice sits under its switch.
        if (!option->choices) return;
        NSView *row = [self choiceRowFor:option];
        DPSet(row, &DPChoicePatchKey, [NSValue valueWithPointer:option]);
        [groups[title] addObject:row];
        [self->_optionChoices addObject:row];
    });
    if (patch->choices) [groups[@"Options"] insertObject:[self choiceRowFor:patch] atIndex:0];
    _rows = patch->rows ? patch->rows() : @[];
    for (NSView *view in _rows) {
        NSView *row = DPRow(view, [NSView new]);
        [view.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12].active = YES;
        [groups[@"Options"] addObject:row];
    }
    if ([titles containsObject:unavailable]) {
        [titles removeObject:unavailable];
        [titles addObject:unavailable];
    }
    for (NSString *title in titles)
        if (groups[title].count) [views addObjectsFromArray:@[DPHeader(title), DPGroup(groups[title])]];

    NSURL *wiki = DPWikiURL(patch);
    NSView *wikiRow = DPLinkRow(DPRow(DPLabel(@"Read more on the wiki", 13, NSFontWeightRegular, NSColor.labelColor),
                                      DPSymbol(@"arrow.up.right", 11, NSColor.secondaryLabelColor)),
                                @"Read more on the wiki", ^{ [NSWorkspace.sharedWorkspace openURL:wiki]; });
    NSTextField *how = DPLabel([@"diatweaks enable " stringByAppendingString:patch->key], 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
    how.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    how.selectable = YES;
    NSView *howRow = DPRow(DPColumn(@[DPLabel(@"Turn on from Terminal", 13, NSFontWeightRegular, NSColor.labelColor), how], 2), [NSStackView new]);
    [views addObject:DPGroup(@[wikiRow, howRow])];

    DPFillStack(self, views);
    [self sync];
    return self;
}

- (NSView *)switchFor:(DPPatch *)patch {
    DPPatchSwitch *toggle = [[DPPatchSwitch alloc] initWithPatch:patch];
    [_switches addObject:toggle];
    return toggle.withHiddenIcon;
}

- (NSView *)choiceRowFor:(DPPatch *)patch {
    NSMenu *menu = patch->choices();
    NSPopUpButton *picker = [NSPopUpButton new];
    picker.menu = menu;
    picker.controlSize = NSControlSizeSmall;
    picker.target = self;
    picker.action = @selector(choose:);
    DPSet(picker, &DPChoicePatchKey, [NSValue valueWithPointer:patch]);
    for (NSMenuItem *item in menu.itemArray) if ([item.representedObject isEqual:DPChoice(patch)]) [picker selectItem:item];
    return DPRow(DPLabel(menu.title, 13, NSFontWeightRegular, NSColor.labelColor), picker);
}

- (void)choose:(NSPopUpButton *)picker {
    DPSetChoice([DPGet(picker, &DPChoicePatchKey) pointerValue] ?: _patch, picker.selectedItem.representedObject);
}

- (void)sync {
    for (DPPatchSwitch *toggle in _switches) [toggle sync];
    for (NSView *row in _rows)
        DPFindView(row, ^BOOL(NSView *view) {
            BOOL label = [view isKindOfClass:NSTextField.class] && !((NSTextField *)view).editable;
            if ([view isKindOfClass:NSControl.class] && !label) ((NSControl *)view).enabled = self->_patch->on;
            return NO;
        });
    for (NSView *row in _optionChoices) {
        BOOL shown = ((DPPatch *)[DPGet(row, &DPChoicePatchKey) pointerValue])->on;
        NSArray<NSView *> *rows = ((NSStackView *)row.superview).arrangedSubviews;
        NSUInteger i = [rows indexOfObject:row];
        row.hidden = !shown;
        if (i != NSNotFound && i > 0) rows[i - 1].hidden = !shown;  // Its separator.
    }
    _note.stringValue = DPWhyDisabled(_patch) ?: @"";
    _note.hidden = !_note.stringValue.length;
}
@end
