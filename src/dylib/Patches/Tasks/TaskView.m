#import "TaskView.h"
#import "AddButton.h"
#import "TaskTable.h"
#import "ComposerField.h"
@implementation DPTaskContent
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) {
        _store=DPTaskStore.shared; _query=@""; _pending=NSMutableSet.new; _records=@[]; _filter=1; _allowed=YES; _wantsInitialFocus=YES;
        _scroll=NSScrollView.new; _scroll.drawsBackground=NO; _scroll.hasVerticalScroller=YES; _scroll.autohidesScrollers=YES;
        _table=DPTaskTable.new; _table.backgroundColor=NSColor.clearColor; _table.headerView=nil; _table.rowHeight=54;
        _table.style=NSTableViewStyleFullWidth; _table.intercellSpacing=NSMakeSize(0,2);
        _table.selectionHighlightStyle=NSTableViewSelectionHighlightStyleNone; _table.dataSource=self; _table.delegate=self;
        NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"task"]; column.minWidth=0; column.resizingMask=NSTableColumnAutoresizingMask; [_table addTableColumn:column];
        _scroll.documentView=_table; [self addSubview:_scroll];
        _empty=[NSTextField wrappingLabelWithString:@"Loading Tasks…"]; _empty.alignment=NSTextAlignmentCenter;
        _empty.textColor=NSColor.secondaryLabelColor; [self addSubview:_empty];
        _composer=NSVisualEffectView.new; _composer.material=NSVisualEffectMaterialPopover;
        _composer.blendingMode=NSVisualEffectBlendingModeWithinWindow; _composer.wantsLayer=YES; _composer.layer.cornerRadius=12; _composer.layer.masksToBounds=YES;
        [self addSubview:_composer];
        _input=DPTaskComposerField.new; _input.placeholderString=@"Add a task…"; _input.accessibilityLabel=@"New task";
        _input.font=[NSFont systemFontOfSize:14]; _input.bordered=NO; _input.drawsBackground=NO; _input.focusRingType=NSFocusRingTypeNone;
        _input.target=self; _input.action=@selector(addTask:); _input.delegate=self; [_composer addSubview:_input];
        _addButton=[DPTaskAddButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.up" accessibilityDescription:nil] target:self action:@selector(addTask:)]; _addButton.bordered=NO; _addButton.accessibilityLabel=@"Add task"; _addButton.toolTip=@"Add task (Return)"; [_composer addSubview:_addButton];
        _addButton.image=[[NSImage imageWithSystemSymbolName:@"arrow.up" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:21 weight:NSFontWeightSemibold]];
        _filterButton=DPLibraryMakeFilterButton(self,@selector(setFilterFromMenu:));
        [_filterButton addItemsWithTitles:@[@"All",@"Incomplete",@"Completed",@"Deleted"]];
        _optionsButton=DPLibraryMakeButton(@"",@"ellipsis",self,@selector(showOptions:));
        _optionsButton.accessibilityLabel=@"Task actions"; _optionsButton.toolTip=@"Task actions";
        __weak DPTaskContent *weak=self;
        _changes=[NSNotificationCenter.defaultCenter addObserverForName:DPTasksChanged object:nil queue:nil usingBlock:^(NSNotification *note){ if(note.object==weak.store) [weak reload]; }];
        _scroll.contentView.postsBoundsChangedNotifications=YES;
        _scrollChanges=[NSNotificationCenter.defaultCenter addObserverForName:NSViewBoundsDidChangeNotification object:_scroll.contentView queue:nil usingBlock:^(NSNotification *note){ DPLibraryReconcileHover(weak.table); weak.table.needsDisplay=YES; }];
        _windowChanges=[NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidResignKeyNotification object:nil queue:nil usingBlock:^(NSNotification *note){ if(note.object==weak.window) DPLibraryReconcileHover(weak.table); }];
        [self reload];
    } return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:_changes]; [NSNotificationCenter.defaultCenter removeObserver:_scrollChanges]; [NSNotificationCenter.defaultCenter removeObserver:_windowChanges]; }
- (BOOL)isFlipped { return YES; }
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if(self.window) { __weak DPTaskContent *weak=self; dispatch_async(dispatch_get_main_queue(),^{ [weak focusInputIfReady]; }); }
}
- (void)focusInputIfReady {
    if(self.wantsInitialFocus && self.input.enabled && self.library.customContent==self && self.library.expanded && !self.library.closing) {
        if([self.window makeFirstResponder:self.input]) self.wantsInitialFocus=NO;
    }
}
- (void)layout {
    [super layout]; CGFloat width=NSWidth(self.bounds),height=NSHeight(self.bounds);
    self.scroll.frame=NSMakeRect(0,0,width,MAX(0,height-66)); [self.scroll layoutSubtreeIfNeeded];
    CGFloat viewport=MAX(0,NSWidth(self.scroll.contentView.bounds));
    self.table.tableColumns.firstObject.width=viewport;
    [self.table setFrameSize:NSMakeSize(viewport,NSHeight(self.table.frame))];
    self.composer.frame=NSMakeRect(8,MAX(0,height-56),MAX(0,width-16),46);
    self.input.frame=NSMakeRect(14,5,MAX(0,NSWidth(self.composer.bounds)-68),36);
    self.addButton.frame=NSMakeRect(MAX(0,NSWidth(self.composer.bounds)-42),7,32,32);
    self.empty.frame=NSMakeRect(24,MAX(20,(height-100)/2),MAX(0,width-48),64);
}
- (void)reload {
    if(self.removing) return;
    NSArray *old=self.records; BOOL animate=self.animateReflow; self.animateReflow=NO;
    self.records=[(self.allowed ? (self.filter==3 ? self.store.cleared : self.store.items) : @[]) filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,id bindings){
        BOOL completed=[item[@"completed"] boolValue];
        return (self.filter==0 || self.filter==3 || (self.filter==1 ? !completed || [self.pending containsObject:item[@"id"]] : completed)) &&
            (!self.query.length || [item[@"text"] rangeOfString:self.query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound);
    }]];
    [self.table reloadData]; if(animate) DPTasksAnimateRows(self.table,old,self.records); self.empty.hidden=self.records.count>0;
    self.empty.stringValue=!self.allowed ? @"Tasks are available in normal browsing windows." : self.store.error ? self.store.error.localizedDescription : !self.store.loaded ? @"Loading Tasks…" : self.query.length ? @"No matching tasks" : self.filter==3 ? @"No deleted tasks" : self.filter==2 ? @"No completed tasks yet" : @"All clear. Add a task below.";
    self.input.enabled=self.allowed && self.store.loaded && !self.store.error; self.addButton.enabled=self.input.enabled && [self.input.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length>0;
    NSString *filter=@[@"All",@"Incomplete",@"Completed",@"Deleted"][self.filter];
    [self.filterButton selectItemAtIndex:self.filter]; self.filterButton.contentTintColor=DPLibraryAccentColor(self.window);
    self.filterButton.accessibilityLabel=[@"Show tasks: " stringByAppendingString:filter]; self.filterButton.toolTip=self.filterButton.accessibilityLabel;
    [self focusInputIfReady];
    self.needsLayout=YES;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)table { return self.records.count; }
- (BOOL)tableView:(NSTableView *)table shouldSelectRow:(NSInteger)row { return NO; }
- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    DPTaskCell *cell=[table makeViewWithIdentifier:@"task" owner:self];
    if(!cell) { cell=DPTaskCell.new; cell.identifier=@"task"; }
    cell.owner=self; cell.deletedItem=self.filter==3; cell.record=self.records[row]; cell.check.hidden=self.filter==3; cell.check.target=self; cell.check.action=@selector(toggleTask:); return cell;
}
- (void)controlTextDidChange:(NSNotification *)note { self.addButton.enabled=[self.input.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length>0; }
- (void)addTask:(id)sender {
    if(self.allowed && [self.store add:self.input.stringValue]) { self.input.stringValue=@""; [self reload]; }
    [self.window makeFirstResponder:self.input];
}
@end
