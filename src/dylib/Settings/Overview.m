#import "Settings.h"

@interface DPOverviewView ()
@property (nonatomic, strong) NSMapTable<DPPatchSwitch *, NSTextField *> *notes;
@property (nonatomic, strong) NSMutableArray<NSArray *> *sections;  // header, group, rows
// Sections whose every tweak is hidden by the same one, like what Hide toolbar hides: the header's eye stands for them all.
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *sectionHiders;
@property (nonatomic, strong) NSMapTable<NSString *, NSImageView *> *sectionEyes;
@property (nonatomic, strong) NSTextField *noResults, *notice;
@end

@implementation DPOverviewView

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.searchText = [NSMapTable strongToStrongObjectsMapTable];
    self.notes = [NSMapTable strongToStrongObjectsMapTable];
    self.sections = [NSMutableArray new];
    self.sectionHiders = [NSMutableDictionary new];
    self.sectionEyes = [NSMapTable strongToStrongObjectsMapTable];
    [DPPreviewView preload];

    NSMutableArray<NSString *> *titles = [NSMutableArray new];
    NSMutableDictionary<NSString *, NSMutableArray<NSView *> *> *rows = [NSMutableDictionary new];
    void (^add)(NSString *, NSView *) = ^(NSString *title, NSView *row) {
        if (!rows[title]) {
            [titles addObject:title];
            rows[title] = [NSMutableArray new];
        }
        [rows[title] addObject:row];
    };
    if (DPSafeMode) add(@"Safe Mode", [self makeSafeModeRow]);
    NSMutableSet<NSString *> *mixed = [NSMutableSet new];
    for (NSUInteger i = 0; i < DPPatchCount; i++) {
        DPPatch *patch = DPPatches[i], *hider = DPPatchNamed(patch->disabledBy);
        if (DPRequired(patch)) continue;
        NSString *section = patch->section ?: @"Other";
        if (rows[section] && self.sectionHiders[section].pointerValue != hider) [mixed addObject:section];
        if (!rows[section]) self.sectionHiders[section] = [NSValue valueWithPointer:hider];
        add(section, [self rowForPatch:patch]);
    }
    for (NSString *section in self.sectionHiders.allKeys)
        if ([mixed containsObject:section] || !self.sectionHiders[section].pointerValue) [self.sectionHiders removeObjectForKey:section];
    for (NSView *row in [self makeUpdateRows]) add(@"Updates", row);

    NSMutableArray<NSView *> *views = [NSMutableArray new];
    for (NSString *title in titles) {
        NSView *header = DPHeader(title);
        if (self.sectionHiders[title]) {
            NSImageView *eye = DPSymbol(@"eye.slash", 12, NSColor.secondaryLabelColor);
            [self.sectionEyes setObject:eye forKey:title];
            NSStackView *row = [NSStackView new];
            [row addView:header inGravity:NSStackViewGravityLeading];
            [row addView:eye inGravity:NSStackViewGravityTrailing];
            header = row;
        }
        NSView *group = DPGroup(rows[title]);
        [views addObjectsFromArray:@[header, group]];
        [self.sections addObject:@[header, group, rows[title]]];
    }
    self.noResults = DPLabel(@"No Results", 13, NSFontWeightRegular, NSColor.secondaryLabelColor);
    self.notice = DPLabel(@"DiaPatches is unofficial and not affiliated with The Browser Company.", 11, NSFontWeightRegular, NSColor.tertiaryLabelColor);
    DPFillStack(self, [views arrayByAddingObjectsFromArray:@[self.noResults, self.notice]]);
    [self syncWithQuery:@""];
    return self;
}

- (NSView *)rowForPatch:(DPPatch *)patch {
    NSTextField *note = DPLabel(@"", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);
    note.hidden = YES;
    NSStackView *leading = [NSStackView stackViewWithViews:@[
        DPIconTile(patch->symbol, [NSColor valueForKey:patch->tint]),
        DPColumn(@[DPLabel(patch->title, 13, NSFontWeightRegular, NSColor.labelColor), note], 2),
    ]];
    leading.spacing = 10;

    DPPatchSwitch *toggle = [[DPPatchSwitch alloc] initWithPatch:patch];
    [self.notes setObject:note forKey:toggle];
    NSMutableString *search = [NSMutableString stringWithFormat:@"%@ %@", patch->title, patch->detail];
    DPForEachOption(patch, ^(DPPatch *option) { [search appendFormat:@" %@ %@", option->title, option->detail]; });
    NSStackView *trailing = [NSStackView stackViewWithViews:@[toggle.withHiddenIcon, DPSymbol(@"chevron.right", 11, NSColor.tertiaryLabelColor)]];
    trailing.spacing = 10;

    __weak DPOverviewView *weakSelf = self;
    NSView *row = DPLinkRow(DPRow(leading, trailing), patch->title, ^{ weakSelf.open(patch->title, [[DPPageView alloc] initWithPatch:patch]); });
    [self.searchText setObject:search forKey:row];
    return row;
}

- (void)syncWithQuery:(NSString *)query {
    for (NSString *section in self.sectionEyes) {
        NSImageView *eye = [self.sectionEyes objectForKey:section];
        eye.toolTip = DPWhyHiddenBy(self.sectionHiders[section].pointerValue);
        eye.hidden = !eye.toolTip;
    }
    for (DPPatchSwitch *toggle in self.notes) {
        [toggle sync];
        if (self.sectionHiders[toggle.patch->section ?: @"Other"]) toggle.hiddenIcon.hidden = YES;
        NSMutableArray<NSString *> *options = [NSMutableArray new];
        if (toggle.patch->on) DPForEachOption(toggle.patch, ^(DPPatch *option) { if (option->on) [options addObject:option->title]; });
        NSTextField *note = [self.notes objectForKey:toggle];
        note.stringValue = DPWhyDisabled(toggle.patch) ?: [options componentsJoinedByString:@" · "];
        note.hidden = !note.stringValue.length;
    }

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
