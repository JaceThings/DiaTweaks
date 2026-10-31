// The Patches row and pane, added to Dia's Settings window after Dia's own sidebar rows.
#import "StdPatch/StdPatch.h"
#import "Updates/Updates.h"
#import "SafeMode/SafeMode.h"

void DPInstallSettings(void);

extern NSToolbarItemIdentifier const DPSearchItemIdentifier;

// Controls.m: the pieces the pane is built from, styled like macOS System Settings.
NSView *DPGroup(NSArray<NSView *> *rows);
NSView *DPRow(NSView *leading, NSView *trailing);
NSView *DPLinkRow(NSView *row, NSString *title, void (^open)(void));  // Clicking anywhere but its controls calls `open`.
NSTextField *DPLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color);
NSView *DPIconTile(NSString *symbol, NSColor *color);
NSImageView *DPSymbol(NSString *symbol, CGFloat size, NSColor *color);
NSStackView *DPColumn(NSArray<NSView *> *views, CGFloat spacing);

@interface DPFlippedView : NSView
@end

// Something with a page: a patch, or a command when `patch` is NULL.
typedef struct {
    DPPatch *patch;
    __unsafe_unretained NSString *key, *title, *detail, *symbol, *tint, *where;
} DPItem;

DPItem DPPatchItem(DPPatch *patch);
NSArray<NSValue *> *DPOptions(DPPatch *patch);  // The patches that require it, shown on its page.
NSString *DPWhyDisabled(DPPatch *patch);        // nil while its switch works.
NSURL *DPWikiURL(DPItem item);

@interface DPPreviewView : NSView
- (instancetype)initWithKey:(NSString *)key;
@end

@interface DPPageView : NSView
- (instancetype)initWithItem:(DPItem)item;
- (void)update;
@end

@interface DPOverviewView : NSView
@property (nonatomic, copy) void (^open)(DPItem item);
@property (nonatomic, strong) NSMapTable<NSView *, NSString *> *searchText;
@property (nonatomic, strong) NSTextField *status;
@property (nonatomic, strong) NSButton *checkButton, *relaunchButton;
- (void)updateWithQuery:(NSString *)query;
@end

@interface DPOverviewView (Updates)
- (NSArray<NSView *> *)makeUpdateRows;
- (NSView *)makeSafeModeRow;
- (void)refresh;
@end

@interface DPPaneView : NSView <NSSearchFieldDelegate>
@property (nonatomic, strong) NSSearchToolbarItem *searchItem;
@property (nonatomic, strong) DPOverviewView *overview;
@property (nonatomic, copy) void (^titleChanged)(NSString *title, BOOL canGoBack);
@property (nonatomic, readonly) BOOL showsPage;
- (void)goBack;
- (void)reset;  // The overview, no search.
@end
