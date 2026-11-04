#import "LittleDia.h"

// Dia's address, drawn like the one in its main window: "site / Page Title", and "site/path" in a soft field under the
// pointer. A click, or ⌘L, edits the whole URL; Return goes, Escape doesn't.
@interface DPAddressView : NSView
@property (nonatomic, weak) NSView *title;
@property (nonatomic) NSTextField *label, *field;
@property (nonatomic) BOOL hovered, beginning, ending;

// Address.m: showing the address.
- (NSURL *)url;
- (void)refresh;
@end

// Edit.m: typing another.
@interface DPAddressView (Edit) <NSTextFieldDelegate>
- (void)begin;
@end
