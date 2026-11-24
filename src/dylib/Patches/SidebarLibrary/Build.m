#import "Library.h"
@implementation DPLibraryController (Build)
- (void)build {
    self.rail = [[NSClassFromString(@"DPLibraryRail") alloc] initWithFrame:NSZeroRect];
    self.rail.wantsLayer = YES;
    [self.view addSubview:self.rail];
    DPLibraryBuildCategories(self);
    NSButton *back = DPLibraryMakeButton(@"",@"arrow.left",self,@selector(close));
    back.identifier = @"back"; back.accessibilityLabel = @"Back to tabs"; back.toolTip = @"Back to tabs (Esc)";
    [self.rail addSubview:back];
    self.sectionHighlight=[NSView new]; self.sectionHighlight.wantsLayer=YES;
    self.sectionHighlight.layer.cornerRadius=12; self.sectionHighlight.layer.cornerCurve=kCACornerCurveContinuous;
    [self.rail addSubview:self.sectionHighlight positioned:NSWindowBelow relativeTo:nil];
    self.options=DPLibraryMakeButton(@"",@"ellipsis",self,@selector(showOptions:));
    self.options.accessibilityLabel=@"Library options"; self.options.toolTip=@"Library options";
    [self.view addSubview:self.options];
    self.search = [[NSSearchField alloc] initWithFrame:NSZeroRect];
    self.search.delegate = self; self.search.placeholderString = @"Search Downloads";
    self.search.accessibilityLabel = @"Search Library"; self.search.sendsSearchStringImmediately = YES;
    [self.view addSubview:self.search];
    self.filter = [[NSClassFromString(@"DPLibraryFilterButton") alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.filter addItemsWithTitles:@[@"All files",@"Complete",@"In progress"]];
    self.filter.target = self; self.filter.action = @selector(filterChanged:); self.filter.accessibilityLabel = @"Filter downloads";
    [self.view addSubview:self.filter];
    DPLibraryBuildInputSurfaces(self);
    self.refresh = DPLibraryMakeRefreshButton(self,@selector(refreshLibrary:));
    self.refresh.accessibilityLabel = @"Refresh Library"; self.refresh.toolTip = @"Refresh Library";
    self.refresh.identifier = @"DiaTweaks.SidebarLibrary.Refresh"; [self.view addSubview:self.refresh];
    self.table = [[NSClassFromString(@"DPLibraryTable") alloc] initWithFrame:NSZeroRect];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"file"];
    column.resizingMask = NSTableColumnAutoresizingMask; [self.table addTableColumn:column];
    self.table.headerView = nil; self.table.rowHeight = 64; self.table.intercellSpacing = NSMakeSize(0,4);
    self.table.backgroundColor = NSColor.clearColor; self.table.style = NSTableViewStyleFullWidth;
    self.table.allowsMultipleSelection = YES; self.table.delegate = self; self.table.dataSource = self;
    self.table.target = self; self.table.doubleAction = @selector(openSelection:);
    self.table.accessibilityLabel = @"Downloads";
    [self.table setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [self.table setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
    self.scroll = [[NSClassFromString(@"DPLibraryScrollView") alloc] initWithFrame:NSZeroRect];
    self.scroll.drawsBackground = NO; self.scroll.hasVerticalScroller = YES; self.scroll.autohidesScrollers = YES;
    self.scroll.documentView = self.table; [self.view addSubview:self.scroll];
    NSCollectionViewFlowLayout *flow = [NSCollectionViewFlowLayout new];
    flow.minimumInteritemSpacing = 12; flow.minimumLineSpacing = 12; flow.sectionInset = NSEdgeInsetsMake(8,8,8,8);
    self.collection = [[NSClassFromString(@"DPLibraryCollection") alloc] initWithFrame:NSZeroRect]; self.collection.collectionViewLayout = flow;
    [self.collection registerClass:DPLibraryMediaItem.class forItemWithIdentifier:@"media"];
    self.collection.selectable = YES; self.collection.allowsMultipleSelection = YES;
    self.collection.delegate = self; self.collection.dataSource = self;
    self.collection.backgroundColors = @[NSColor.clearColor]; self.collection.accessibilityLabel = @"Downloaded media";
    [self.collection setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [self.collection setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
    self.mediaScroll = [[NSClassFromString(@"DPLibraryScrollView") alloc] initWithFrame:NSZeroRect]; self.mediaScroll.drawsBackground = NO;
    self.mediaScroll.hasVerticalScroller = YES; self.mediaScroll.autohidesScrollers = YES;
    self.mediaScroll.documentView = self.collection; [self.view addSubview:self.mediaScroll];
    self.empty = [NSTextField wrappingLabelWithString:@"No downloads yet"];
    self.empty.alignment = NSTextAlignmentCenter; self.empty.textColor = NSColor.secondaryLabelColor;
    self.empty.font = [NSFont systemFontOfSize:14]; [self.view addSubview:self.empty];
}
- (void)chooseSection:(NSButton *)sender {
    [self.table deselectAll:nil]; self.collection.selectionIndexes = NSIndexSet.indexSet;
    self.showHidden=NO; self.layoutSignature=nil;
    NSArray *names=DPLibrarySectionNames();
    self.section = names[MIN((NSInteger)names.count-1,MAX(0,sender.tag))];
    [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] setObject:self.section forKey:@"sidebarLibrarySection"];
    if ([self.section isEqual:@"Archived Tabs"]) {
        NSUInteger generation = ++self.archiveGeneration; NSString *profile = self.context;
        __weak DPLibraryController *weak = self;
        DPLibraryLoadArchive(profile,^(NSArray *records) {
            if (weak.archiveGeneration != generation || ![weak.context isEqual:profile]) return;
            weak.archive = records; [weak reload];
        });
    }
    for (NSView *view in self.rail.subviews) if ([view isKindOfClass:NSButton.class] && ![view.identifier isEqual:@"back"])
        [(NSButton *)view setState:view == sender];
    DPLibraryMoveSectionHighlight(self,YES);
    self.search.stringValue = @"";
    [self.filter removeAllItems];
    [self.filter addItemsWithTitles:[self.section isEqual:@"Archived Tabs"] ? @[@"All dates",@"Today",@"Past week",@"Past month"] : @[@"All files",@"Complete",@"In progress"]];
    [self.filter selectItemAtIndex:0]; self.filterIndex = 0; [self reload];
    if(self.preferredSectionResponder) [self.window makeFirstResponder:self.preferredSectionResponder];
}
- (void)filterChanged:(id)sender { self.filterIndex = self.filter.indexOfSelectedItem; [self reload]; }
@end
