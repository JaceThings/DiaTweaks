// The Patches row and pane, added to Dia's Settings window after Dia's own sidebar rows.
#import "StdPatch/StdPatch.h"
#import "Updates/Updates.h"
#import "SafeMode/SafeMode.h"

void DPInstallSettings(void);

extern NSToolbarItemIdentifier const DPSearchItemIdentifier;

// Controls.m: the pieces the pane is built from, styled like macOS System Settings.
NSView *DPGroup(NSArray<NSView *> *rows);
NSView *DPRow(NSView *leading, NSView *trailing);
NSTextField *DPLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color);
NSView *DPIconTile(NSString *symbol, NSColor *color);

@interface DPFlippedView : NSView
@end

@interface DPPaneView : NSView <NSSearchFieldDelegate>
@property (nonatomic, strong) NSSearchToolbarItem *searchItem;
@property (nonatomic, strong) NSArray<NSSwitch *> *toggles;
@property (nonatomic, strong) NSArray<NSArray *> *sections;  // header, group, rows
@property (nonatomic, strong) NSMapTable<NSView *, NSString *> *searchText;
@property (nonatomic, strong) NSTextField *noResults, *notice, *status;
@property (nonatomic, strong) NSButton *checkButton, *relaunchButton;
@end

@interface DPPaneView (Search)
- (void)updateRows;
@end

@interface DPPaneView (Updates)
- (NSArray<NSView *> *)makeUpdateRows;
- (NSView *)makeSafeModeRow;
- (void)refresh;
@end
