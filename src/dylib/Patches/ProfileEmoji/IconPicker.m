#import "ProfileIcons.h"

@interface DPProfileIconGrid : NSView
@end
@implementation DPProfileIconGrid
- (BOOL)isFlipped { return YES; }
@end

@implementation DPProfileIconPicker {
    NSSearchField *_search;
    NSScrollView *_scroll;
    NSArray<NSString *> *_symbols;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 344)];
    _search = [[NSSearchField alloc] initWithFrame:NSMakeRect(16, 300, 288, 28)];
    _search.placeholderString = @"Search symbols by name";
    _search.accessibilityLabel = @"Search profile icons";
    _search.delegate = self;
    _search.sendsSearchStringImmediately = YES;
    [self.view addSubview:_search];
    _scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 48, 288, 240)];
    _scroll.hasVerticalScroller = YES;
    _scroll.drawsBackground = NO;
    [self.view addSubview:_scroll];
    NSTextField *hint = [NSTextField wrappingLabelWithString:@"Browse icons, or search with an exact SF Symbol name."];
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = NSColor.secondaryLabelColor;
    hint.frame = NSMakeRect(16, 10, 288, 30);
    [self.view addSubview:hint];
    NSArray *names = [@"person person.2 house building.2 briefcase backpack graduationcap book books.vertical bookmark folder tray archivebox doc note.text calendar clock alarm bell flag tag pin mappin map globe location compass airplane car bicycle tram ferry figure.walk figure.run heart star sparkles bolt flame sun.max moon moon.stars cloud cloud.sun snowflake drop leaf tree flower pawprint cat dog fish bird mountain.2 tent beach.umbrella cup.and.saucer mug fork.knife birthday.cake gift cart basket creditcard banknote chart.bar chart.pie gamecontroller puzzlepiece.extension dice trophy medal music.note music.note.list headphones mic film tv camera photo paintbrush paintpalette pencil ruler scissors wrench.and.screwdriver hammer gearshape terminal chevron.left.forwardslash.chevron.right curlybraces desktopcomputer laptopcomputer keyboard iphone lightbulb paperplane envelope bubble.left lock key shield checkmark.seal atom network wifi antenna.radiowaves.left.and.right externaldrive internaldrive opticaldisc infinity circle square triangle hexagon diamond cube shippingbox" componentsSeparatedByString:@" "];
    NSMutableArray *available = [NSMutableArray array];
    for (NSString *name in names) {
        NSString *symbol = DPProfilePreferredSymbolName(name);
        if (symbol && ![available containsObject:symbol]) [available addObject:symbol];
    }
    _symbols = available;
    [self reloadSymbols];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window makeFirstResponder:_search];
}

- (void)controlTextDidChange:(NSNotification *)note { [self reloadSymbols]; }

- (void)reloadSymbols {
    NSString *query = [[_search.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    for (NSString *name in _symbols) if (!query.length || [name containsString:query]) [matches addObject:name];
    NSString *exact = DPProfilePreferredSymbolName(query);
    if (exact && ![matches containsObject:exact]) [matches insertObject:exact atIndex:0];
    CGFloat width = NSWidth(_scroll.contentView.bounds);
    NSInteger columns = MAX(1, (NSInteger)(width / 36));
    NSString *selected = DPProfilePreferredSymbolName(self.selectedName);
    NSView *grid = [[DPProfileIconGrid alloc] initWithFrame:NSMakeRect(0, 0, width, MAX(240, ((matches.count + columns - 1) / columns) * 36))];
    for (NSUInteger i = 0; i < matches.count; i++) {
        NSString *name = matches[i];
        NSButton *button = [NSButton buttonWithImage:DPProfileSymbolImage(name, 16) target:self action:@selector(symbol:)];
        button.frame = NSMakeRect((i % columns) * 36, (i / columns) * 36, 36, 36);
        button.bezelStyle = NSBezelStyleRecessed;
        button.showsBorderOnlyWhileMouseInside = YES;
        [button setButtonType:NSButtonTypePushOnPushOff];
        button.state = [name isEqual:selected] ? NSControlStateValueOn : NSControlStateValueOff;
        button.contentTintColor = NSColor.labelColor;
        button.toolTip = name;
        button.accessibilityLabel = name;
        button.identifier = name;
        [grid addSubview:button];
    }
    if (!matches.count) {
        NSTextField *empty = [NSTextField wrappingLabelWithString:@"No symbols found. Try another name. Availability depends on your macOS version."];
        empty.textColor = NSColor.secondaryLabelColor;
        empty.frame = NSMakeRect(8, 16, width - 16, 60);
        [grid addSubview:empty];
    }
    _scroll.documentView = grid;
    [_scroll.contentView scrollToPoint:NSZeroPoint];
}

- (void)symbol:(NSButton *)sender {
    if (self.selection) self.selection(sender.identifier);
}
@end
