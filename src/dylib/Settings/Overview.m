#import "Settings.h"

static const DPItem DPGroupTabsItem = {
    NULL, @"groupTabsByDomain", @"Group Tabs by Domain", @"Group a window’s tabs by site.", @"rectangle.3.group", @"systemGreenColor",
    @"Right-click a tab, or choose Tabs → Group Tabs by Domain.",
};

@interface DPOverviewRow : NSObject
@property (nonatomic, strong) NSView *view;
@property (nonatomic, strong) NSSwitch *toggle;
@property (nonatomic, strong) NSTextField *note;
@property (nonatomic) DPPatch *patch;
@end
@implementation DPOverviewRow
@end

@interface DPOverviewView ()
@property (nonatomic, strong) NSMutableArray<DPOverviewRow *> *rows;
@property (nonatomic, strong) NSArray<NSArray *> *sections;  // header, group, rows
@property (nonatomic, strong) NSTextField *noResults, *notice;
@end

@implementation DPOverviewView

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.searchText = [NSMapTable strongToStrongObjectsMapTable];
    self.rows = [NSMutableArray new];
    NSMutableArray<NSArray *> *groups = [NSMutableArray new];
    if (DPSafeMode) [groups addObject:@[@"Safe Mode", @[[self makeSafeModeRow]]]];
    NSMutableDictionary<NSString *, NSMutableArray *> *bySection = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < DPPatchCount; i++) {
        DPPatch *patch = DPPatches[i];
        if (DPRequired(patch)) continue;
        NSString *section = patch->section ?: @"Other";
        if (!bySection[section]) [groups addObject:@[section, bySection[section] = [NSMutableArray new]]];
        [bySection[section] addObject:[self rowForItem:DPPatchItem(patch)]];
    }
    [groups addObject:@[@"Commands", @[[self rowForItem:DPGroupTabsItem]]]];
    [groups addObject:@[@"Updates", [self makeUpdateRows]]];

    self.noResults = DPLabel(@"No Results", 13, NSFontWeightRegular, NSColor.secondaryLabelColor);
    self.notice = DPLabel(@"DiaPatches is unofficial and not affiliated with The Browser Company.", 11, NSFontWeightRegular, NSColor.tertiaryLabelColor);
    NSMutableArray<NSView *> *views = [NSMutableArray new];
    NSMutableArray<NSArray *> *sections = [NSMutableArray new];
    for (NSArray *section in groups) {
        NSTextField *header = DPLabel(section[0], 12, NSFontWeightSemibold, NSColor.secondaryLabelColor);
        NSView *group = DPGroup(section[1]);
        [views addObjectsFromArray:@[header, group]];
        [sections addObject:@[header, group, section[1]]];
    }
    [views addObjectsFromArray:@[self.noResults, self.notice]];
    self.sections = sections;
    NSStackView *content = DPColumn(views, 8);
    content.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSView *v in views) [v.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    [self addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:self.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];
    [self updateWithQuery:@""];
    return self;
}

- (NSView *)rowForItem:(DPItem)item {
    DPOverviewRow *row = [DPOverviewRow new];
    row.patch = item.patch;
    row.note = DPLabel(@"", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);
    row.note.hidden = YES;
    NSStackView *leading = [NSStackView stackViewWithViews:@[
        DPIconTile(item.symbol, [NSColor valueForKey:item.tint]),
        DPColumn(@[DPLabel(item.title, 13, NSFontWeightRegular, NSColor.labelColor), row.note], 2),
    ]];
    leading.spacing = 10;
    NSView *control = DPLabel(@"Tabs menu", 13, NSFontWeightRegular, NSColor.secondaryLabelColor);
    NSMutableString *search = [NSMutableString stringWithFormat:@"%@ %@", item.title, item.detail];
    if (item.patch) {
        row.toggle = [NSSwitch new];
        row.toggle.controlSize = NSControlSizeSmall;
        row.toggle.target = self;
        row.toggle.action = @selector(toggle:);
        row.toggle.accessibilityLabel = item.title;
        control = row.toggle;
        for (NSValue *option in DPOptions(item.patch))
            [search appendFormat:@" %@ %@", ((DPPatch *)option.pointerValue)->title, ((DPPatch *)option.pointerValue)->detail];
    }
    NSStackView *trailing = [NSStackView stackViewWithViews:@[control, DPSymbol(@"chevron.right", 11, NSColor.tertiaryLabelColor)]];
    trailing.spacing = 10;
    __weak DPOverviewView *weakSelf = self;
    row.view = DPLinkRow(DPRow(leading, trailing), item.title, ^{ weakSelf.open(item); });
    [self.searchText setObject:search forKey:row.view];
    [self.rows addObject:row];
    return row.view;
}

- (void)toggle:(NSSwitch *)sender {
    for (DPOverviewRow *row in self.rows)
        if (row.toggle == sender) DPSetPatch(row.patch, sender.state == NSControlStateValueOn, YES);
    [NSNotificationCenter.defaultCenter postNotificationName:DPPatchesDidChangeNotification object:nil];
}

// The summary names the options that are on; a reason replaces it while the switch can't be used.
- (void)updateRow:(DPOverviewRow *)row {
    DPPatch *patch = row.patch;
    if (!patch) return;
    NSMutableArray<NSString *> *on = [NSMutableArray new];
    for (NSValue *option in DPOptions(patch))
        if (patch->on && ((DPPatch *)option.pointerValue)->on) [on addObject:((DPPatch *)option.pointerValue)->title];
    row.toggle.state = patch->on;
    row.toggle.enabled = !DPWhyDisabled(patch);
    row.note.stringValue = DPWhyDisabled(patch) ?: [on componentsJoinedByString:@" · "];
    row.note.hidden = !row.note.stringValue.length;
}

- (void)updateWithQuery:(NSString *)query {
    for (DPOverviewRow *row in self.rows) [self updateRow:row];
    NSArray<NSString *> *words = [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    BOOL anything = NO;
    for (NSArray *section in self.sections) {
        BOOL any = NO;
        for (NSView *row in section[2]) {
            BOOL visible = YES;
            for (NSString *word in words) visible &= !word.length || [[self.searchText objectForKey:row] localizedStandardContainsString:word];
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
    self.notice.hidden = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length > 0;
}
@end
