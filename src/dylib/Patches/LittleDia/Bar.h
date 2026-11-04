#import "LittleDia.h"

// One per popup bar: the buttons around Dia's address, which keeps its own look and Dia's updates to it.
@interface DPLittleBar : NSObject
@property (nonatomic, weak) NSView *title;
@property (nonatomic) NSArray<NSButton *> *leading;  // close, back, forward, reload
@property (nonatomic) NSButton *open;
@property (nonatomic) NSView *address;
@property (nonatomic) NSView *divider;
@property (nonatomic) NSTimer *timer;
@end

static const CGFloat DPInset = 6, DPGap = 2, DPButton = 28;
extern char DPBarKey;  // The DPLittleBar on Dia's address view.

// Bar.m: the buttons and address around Dia's own, and taking them away again.
DPLittleBar *DPMakeBar(NSView *title);
void DPPlaceBar(DPLittleBar *bar);
void DPRemoveBar(NSView *title);
