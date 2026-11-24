#import "Tasks.h"
#import "Patches/SidebarLibrary/Library.h"
@interface DPTaskContent : NSView <NSTableViewDataSource,NSTableViewDelegate,NSTextFieldDelegate>
@property(weak) DPLibraryController *library;
@property DPTaskStore *store;
@property NSScrollView *scroll;
@property NSTableView *table;
@property NSTextField *input,*empty;
@property NSVisualEffectView *composer;
@property NSButton *addButton,*optionsButton;
@property NSPopUpButton *filterButton;
@property NSArray<NSDictionary *> *records;
@property NSMutableSet<NSString *> *pending;
@property NSString *query;
@property NSInteger filter;
@property BOOL allowed,removing,animateReflow;
@property BOOL wantsInitialFocus;
@property id changes,scrollChanges,windowChanges;
- (void)reload;
- (void)addTask:(id)sender;
@end
@interface DPTaskContent (Actions)
- (void)toggleTask:(NSButton *)sender;
- (void)chooseFilter:(id)sender;
- (void)showOptions:(id)sender;
- (void)clearTasks:(id)sender;
- (void)restoreTasks:(id)sender;
- (void)clearCompletedTasks:(id)sender;
@end
@interface DPTaskCell : NSTableCellView
@property NSButton *check;
@property(weak) DPTaskContent *owner;
@property BOOL deletedItem,editing;
@property(nonatomic) NSDictionary *record;
- (void)dpLibraryUpdatePointerHover;
- (void)startEditing:(id)sender;
- (void)deleteTask:(id)sender;
- (void)restoreTask:(id)sender;
- (void)commitEditing:(id)sender;
@end

@interface DPTaskContent (Removal)
- (void)performRemoval:(NSArray<NSView *> *)views mutation:(void (^)(void))mutation;
@end
void DPTasksAnimateRows(NSTableView *table,NSArray *old,NSArray *current);
