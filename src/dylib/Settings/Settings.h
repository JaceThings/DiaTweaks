#import "../DiaPatches.h"

extern NSToolbarItemIdentifier const DPSearchItemIdentifier;

@interface DPPaneView : NSView
@property (nonatomic, strong) NSSearchToolbarItem *searchItem;
- (void)refresh;
- (void)updateRows;
@end

@interface DPSidebarRow : NSControl
@property (nonatomic) BOOL selected;
@property (nonatomic, strong) NSImageView *icon;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic) NSRect iconFrame, labelFrame, pillFrame;
@property (nonatomic, strong) NSFont *labelFont;
@property (nonatomic) CGFloat pillRadius;
@end
