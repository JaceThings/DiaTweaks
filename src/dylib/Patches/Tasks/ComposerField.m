#import "ComposerField.h"
@interface DPTaskComposerCell : NSTextFieldCell @end
@implementation DPTaskComposerCell
- (NSRect)drawingRectForBounds:(NSRect)rect {
    NSRect drawing=[super drawingRectForBounds:rect];
    CGFloat height=ceil([self cellSizeForBounds:rect].height);
    drawing.origin.y=NSMidY(rect)-height/2;
    drawing.size.height=height; return drawing;
}
- (void)selectWithFrame:(NSRect)rect inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate start:(NSInteger)start length:(NSInteger)length {
    [super selectWithFrame:[self drawingRectForBounds:rect] inView:view editor:editor delegate:delegate start:start length:length];
}
- (void)editWithFrame:(NSRect)rect inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate event:(NSEvent *)event {
    [super editWithFrame:[self drawingRectForBounds:rect] inView:view editor:editor delegate:delegate event:event];
}
@end
@implementation DPTaskComposerField
+ (Class)cellClass { return DPTaskComposerCell.class; }
@end
