// The Boost popover for one site. Editor.m keeps the state and handles the controls, EditorView.m lays it out from
// Settings' own rows and groups.
#import "Patches/Boosts/Boosts.h"
#import "Settings/Settings.h"

@interface DPBoostEditor : NSViewController <NSPopoverDelegate, NSTextViewDelegate>
@property (nonatomic, copy) NSString *domain;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, weak) NSWindow *browserWindow;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *zaps;
@property (nonatomic, weak) id zapping;  // The tab whose clicks hide things, until Escape, Done or the popover closing.
@property (nonatomic, strong) NSSwitch *enabled;
@property (nonatomic, strong) NSStackView *zapRows;  // A row per thing hidden, in zapScroll.
@property (nonatomic, strong) NSScrollView *zapScroll;
@property (nonatomic, strong) NSTextField *zapHow;
@property (nonatomic, strong) NSButton *zapButton;
@property (nonatomic, strong) NSPopUpButton *font;
@property (nonatomic, strong) NSTextView *css, *js;
- (void)save;
@end

@interface DPBoostEditor (Layout)  // EditorView.m
- (NSView *)makeContent:(NSDictionary *)boost;
- (void)showZapping;  // The Zap row's text and button, for whether it's zapping.
- (void)addZapRow:(NSDictionary *)zap animated:(BOOL)animated;
@end
