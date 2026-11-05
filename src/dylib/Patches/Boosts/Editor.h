// The Boost popover for one site. Editor.m keeps the state and handles the controls, EditorView.m lays it out from
// Settings' own rows and groups.
#import "Patches/Boosts/Boosts.h"
#import "Settings/Settings.h"

@interface DPBoostEditor : NSViewController <NSPopoverDelegate, NSTextViewDelegate>
@property (nonatomic, copy) NSString *domain;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, weak) NSWindow *browserWindow;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *zaps;
@property (nonatomic, strong) NSSwitch *enabled;
@property (nonatomic, strong) NSStackView *zapList;
@property (nonatomic, strong) NSPopUpButton *font;
@property (nonatomic, strong) NSTextView *css, *js;
@end

@interface DPBoostEditor (Layout)  // EditorView.m
- (NSView *)makeContent:(NSDictionary *)boost;
- (void)reloadZapList;
@end
