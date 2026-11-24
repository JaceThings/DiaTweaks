#import "LibraryUI.h"
#import "Patches/SidebarLibrary/Library.h"
@interface DPEaselCardGrid : NSView @end
@implementation DPEaselCardGrid
- (BOOL)isFlipped { return YES; }
@end
@implementation DPEaselLibraryContent
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) {
        _undo=NSUndoManager.new; _records=@[]; _query=@"";
        _scroll=NSScrollView.new; _scroll.drawsBackground=NO; _scroll.hasVerticalScroller=YES; _scroll.autohidesScrollers=YES;
        _grid=DPEaselCardGrid.new; _scroll.documentView=_grid; [self addSubview:_scroll];
        _empty=[NSTextField wrappingLabelWithString:@"Loading Easels…"]; _empty.alignment=NSTextAlignmentCenter; _empty.textColor=NSColor.secondaryLabelColor; [self addSubview:_empty];
        _emptyIcon=[NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"pencil.and.outline" accessibilityDescription:@"Easels"]]; [self addSubview:_emptyIcon];
        _create=[NSButton buttonWithTitle:@"New Easel" target:self action:@selector(newEasel:)]; _create.bezelStyle=NSBezelStyleRounded; [self addSubview:_create];
        _importButton=DPLibraryMakeButton(@"",@"square.and.arrow.down",self,@selector(importEasel:)); _importButton.toolTip=@"Import Easel"; _importButton.accessibilityLabel=@"Import Easel";
        _recovery=DPLibraryMakeButton(@"",@"trash",self,@selector(toggleTrash:));
        _recovery.identifier=@"persistentSelection";
        _recovery.accessibilityLabel=@"Recently Deleted Easels"; _recovery.toolTip=@"Recently Deleted Easels";
        __weak DPEaselLibraryContent *weak=self;
        _changes=[NSNotificationCenter.defaultCenter addObserverForName:DPEaselCatalogChanged object:nil queue:nil usingBlock:^(NSNotification *note){
            DPEaselLibraryContent *view=weak; view.loaded=NO; if(view.window && !view.hiddenOrHasHiddenAncestor) [view reload];
        }];
        _scroll.contentView.postsBoundsChangedNotifications=YES;
        _scrollChanges=[NSNotificationCenter.defaultCenter addObserverForName:NSViewBoundsDidChangeNotification object:_scroll.contentView queue:nil usingBlock:^(NSNotification *note){
            for(DPEaselCard *card in weak.grid.subviews) [card reconcileHover];
        }];
    }
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:_changes]; [NSNotificationCenter.defaultCenter removeObserver:_scrollChanges]; }
- (BOOL)isFlipped { return YES; }
- (void)layout {
    [super layout]; self.scroll.frame=self.bounds;
    // Use the new clip viewport in this pass, not its previous width. A Library
    // reveal/settle can otherwise show one frame with cards cropped on the right.
    [self.scroll layoutSubtreeIfNeeded];
    CGFloat width=NSWidth(self.scroll.contentView.bounds); NSUInteger columns=width>=330 ? 2 : 1;
    CGFloat cardWidth=MAX(80,(width-16*(columns+1))/columns),height=MAX(150,MIN(190,cardWidth));
    NSUInteger index=0; for(DPEaselCard *card in self.grid.subviews) {
        NSRect frame=NSMakeRect(16+(index%columns)*(cardWidth+16),16+(index/columns)*(height+16),cardWidth,height);
        if(self.animateReflow && !NSIsEmptyRect(card.frame)) [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){ context.duration=.18; card.animator.frame=frame; } completionHandler:nil]; else card.frame=frame;
        card.restoreButton.frame=NSMakeRect(MAX(12,cardWidth-88),16,72,26); index++;
    }
    self.animateReflow=NO;
    NSUInteger rows=(index+columns-1)/columns;
    self.grid.frame=NSMakeRect(0,0,width,MAX(NSHeight(self.scroll.contentView.bounds),16+rows*(height+16)));
    CGFloat middle=MAX(100,NSHeight(self.bounds)/2);
    self.emptyIcon.frame=NSMakeRect((NSWidth(self.bounds)-34)/2,middle-80,34,34);
    self.empty.frame=NSMakeRect(24,middle-32,MAX(20,NSWidth(self.bounds)-48),64);
    self.create.frame=NSMakeRect((NSWidth(self.bounds)-120)/2,middle+42,120,32);
}
- (void)reload {
    if(self.removing) return;
    if(!self.allowed) { self.records=@[]; self.loaded=YES; [self displayRecords]; return; }
    if(self.loaded) { [self displayRecords]; return; }
    self.loaded=YES; NSUInteger generation=++self.generation;
    __weak DPEaselLibraryContent *weak=self;
    void (^completion)(NSArray *,NSError *)=^(NSArray *records,NSError *error){
        DPEaselLibraryContent *view=weak; if(!view || generation!=view.generation || !view.allowed) return;
        view.records=records; [view displayRecords];
        if(error) view.empty.stringValue=@"Couldn’t load Easels. Reopen Library to try again.";
    };
    if(self.showTrash) [DPEaselStore.shared listTrashed:completion]; else [DPEaselStore.shared list:completion];
}
- (void)displayRecords {
    NSArray *records=[self.records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *record,id bindings){
        if(![(record[@"profile"] ?: @"Profile 1") isEqual:self.profile]) return NO;
        return !self.query.length || [record[@"title"] rangeOfString:self.query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound;
    }]];
    NSMutableDictionary *existing=NSMutableDictionary.new;
    for(DPEaselCard *card in self.grid.subviews) existing[card.record[@"id"]]=card;
    NSMutableArray *ordered=NSMutableArray.new;
    for(NSDictionary *record in records) {
        DPEaselCard *card=existing[record[@"id"]];
        if(!card) { card=DPEaselCard.new; card.owner=self; card.accessibilityRole=NSAccessibilityButtonRole; }
        [existing removeObjectForKey:record[@"id"]];
        card.hidden=NO; card.trashed=self.showTrash;
        if(self.showTrash && !card.restoreButton) {
            card.restoreButton=[NSButton buttonWithTitle:@"Restore" target:card action:@selector(restoreFromMenu:)];
            card.restoreButton.bezelStyle=NSBezelStyleRounded; card.restoreButton.accessibilityLabel=@"Restore Easel"; [card addSubview:card.restoreButton];
        }
        card.restoreButton.hidden=!self.showTrash;
        card.accessibilityLabel=self.showTrash ? [@"Deleted Easel: " stringByAppendingString:record[@"title"]] : record[@"title"];
        if(![card.record isEqual:record]) { card.record=record; card.needsDisplay=YES; }
        [ordered addObject:card];
    }
    for(NSView *removed in existing.allValues) [removed removeFromSuperview];
    // Reordering existing cards preserves pointer/accessibility identity on autosave.
    if(![self.grid.subviews isEqual:ordered]) [self.grid setSubviews:ordered];
    BOOL empty=!records.count; self.empty.hidden=!empty; self.emptyIcon.hidden=!empty; self.create.hidden=!empty || self.query.length || !self.allowed || self.showTrash;
    self.recovery.hidden=!self.allowed; self.recovery.state=self.showTrash; self.recovery.contentTintColor=self.showTrash ? DPLibraryAccentColor(self.window) : NSColor.labelColor; self.recovery.needsDisplay=YES;
    self.recovery.accessibilityLabel=self.showTrash ? @"Back to Easels" : @"Recently Deleted Easels";
    self.recovery.toolTip=self.recovery.accessibilityLabel;
    self.empty.stringValue=!self.allowed ? @"Easels are available in normal browsing windows." : self.query.length ? @"No matching Easels" : self.showTrash ? @"No recently deleted Easels." : @"No Easels yet. Collect images, text and drawings in your first board.";
    self.needsLayout=YES;
}
@end
