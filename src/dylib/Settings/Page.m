#import "Settings.h"

// A patch's or command's own page: its preview, its switch and options, and where to read more.
@interface DPPageView ()
@property (nonatomic) DPItem item;
@property (nonatomic, strong) NSMapTable<NSSwitch *, NSValue *> *switches;
@property (nonatomic, strong) NSTextField *note;
@end

@implementation DPPageView

- (instancetype)initWithItem:(DPItem)item {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.item = item;
    self.switches = [NSMapTable strongToStrongObjectsMapTable];
    self.note = DPLabel(@"", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);

    DPPreviewView *preview = [[DPPreviewView alloc] initWithKey:item.key];
    [preview.heightAnchor constraintEqualToAnchor:preview.widthAnchor multiplier:10.0 / 16].active = YES;
    NSStackView *heading = [NSStackView stackViewWithViews:@[
        DPIconTile(item.symbol, [NSColor valueForKey:item.tint]),
        DPColumn(@[DPLabel(item.title, 13, NSFontWeightSemibold, NSColor.labelColor),
                   DPLabel(item.detail, 11, NSFontWeightRegular, NSColor.secondaryLabelColor), self.note], 2),
    ]];
    heading.spacing = 10;
    heading.alignment = NSLayoutAttributeTop;
    NSMutableArray<NSView *> *views = [NSMutableArray arrayWithArray:@[preview, DPGroup(@[DPRow(heading, [self switchFor:item.patch])])]];

    NSArray<NSValue *> *options = item.patch ? DPOptions(item.patch) : @[];
    if (options.count) {
        NSMutableArray<NSView *> *rows = [NSMutableArray new];
        for (NSValue *option in options) {
            DPPatch *patch = option.pointerValue;
            NSView *text = DPColumn(@[DPLabel(patch->title, 13, NSFontWeightRegular, NSColor.labelColor),
                                      DPLabel(patch->detail, 11, NSFontWeightRegular, NSColor.secondaryLabelColor)], 2);
            [rows addObject:DPRow(text, [self switchFor:patch])];
        }
        [views addObjectsFromArray:@[DPLabel(@"Options", 12, NSFontWeightSemibold, NSColor.secondaryLabelColor), DPGroup(rows)]];
    }

    NSURL *wiki = DPWikiURL(item);
    NSView *wikiRow = DPLinkRow(DPRow(DPLabel(@"Read more on the wiki", 13, NSFontWeightRegular, NSColor.labelColor),
                                      DPSymbol(@"arrow.up.right", 11, NSColor.secondaryLabelColor)),
                                @"Read more on the wiki", ^{ [NSWorkspace.sharedWorkspace openURL:wiki]; });
    NSTextField *how = DPLabel(item.where ?: [@"diatweaks enable " stringByAppendingString:item.key], 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
    if (!item.where) how.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    how.selectable = YES;
    NSView *howRow = DPRow(DPColumn(@[DPLabel(item.where ? @"Use it" : @"Turn on from Terminal", 13, NSFontWeightRegular, NSColor.labelColor), how], 2), [NSStackView new]);
    [views addObject:DPGroup(@[wikiRow, howRow])];

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
    [self update];
    return self;
}

- (NSView *)switchFor:(DPPatch *)patch {
    if (!patch) return [NSStackView new];
    NSSwitch *toggle = [NSSwitch new];
    toggle.controlSize = NSControlSizeSmall;
    toggle.target = self;
    toggle.action = @selector(toggle:);
    toggle.accessibilityLabel = patch->title;
    [self.switches setObject:[NSValue valueWithPointer:patch] forKey:toggle];
    return toggle;
}

- (void)toggle:(NSSwitch *)sender {
    DPSetPatch([self.switches objectForKey:sender].pointerValue, sender.state == NSControlStateValueOn, YES);
    [NSNotificationCenter.defaultCenter postNotificationName:DPPatchesDidChangeNotification object:nil];
}

// Options only work while the page's own patch is on.
- (void)update {
    DPPatch *main = self.item.patch;
    for (NSSwitch *toggle in self.switches) {
        DPPatch *patch = [self.switches objectForKey:toggle].pointerValue;
        toggle.state = patch->on;
        toggle.enabled = !DPWhyDisabled(patch) && (patch == main || main->on);
    }
    self.note.stringValue = main ? DPWhyDisabled(main) ?: @"" : @"";
    self.note.hidden = !self.note.stringValue.length;
}
@end
