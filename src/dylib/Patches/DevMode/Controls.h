#import "DevMode.h"

@interface DPHueSlider : NSControl
@property (nonatomic) CGFloat value;
@property (nonatomic) BOOL selected;
@end

@interface DPSwatch : NSControl
@property (nonatomic) NSImage *image;
@property (nonatomic) NSColor *color;
@property (nonatomic) BOOL selected;
@property (nonatomic, copy) NSString *label;
@end

void DPShowTip(NSView *anchor, NSString *text, NSString *keys);
void DPHideTip(void);

void DPShowBubble(NSView *anchor, NSView *content);
void DPCloseBubble(void);
BOOL DPBubbleShown(void);
