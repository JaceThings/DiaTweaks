#import "../DiaPatches.h"

extern NSToolbarItemIdentifier const DPSearchItemIdentifier;

@interface DPPaneView : NSView
@property (nonatomic, strong) NSSearchToolbarItem *searchItem;
- (void)refresh;
- (void)updateRows;
@end
