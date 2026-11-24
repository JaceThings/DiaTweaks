#import "Canvas.h"
@implementation DPEaselEditorSurface (SlideScaling)
- (void)fitSlideToViewport {
    NSSize logical=self.canvas.document.canvasSize;
    NSSize viewport = self.scroll.contentView.bounds.size;
    if (viewport.width < 1 || viewport.height < 1 || logical.width < 1 || logical.height < 1) return;
    // In tall, narrow splits a width-only fit leaves undrawable scroll-view background.
    // Cover the viewport uniformly and let the scroll view expose the rest of the board.
    CGFloat scale = MAX(viewport.width / logical.width, viewport.height / logical.height);
    NSPoint anchor = self.canvas.visibleRect.origin;
    NSSize displayed = NSMakeSize(logical.width * scale, logical.height * scale);
    if (fabs(NSWidth(self.canvas.frame) - displayed.width) < .01 && fabs(NSHeight(self.canvas.frame) - displayed.height) < .01 && NSEqualSizes(self.canvas.bounds.size, logical)) return;
    [self.canvas setFrameSize:displayed];
    [self.canvas setBounds:NSMakeRect(0, 0, logical.width, logical.height)];
    anchor.x = MIN(anchor.x, MAX(0, logical.width - viewport.width / scale));
    anchor.y = MIN(anchor.y, MAX(0, logical.height - viewport.height / scale));
    [self.canvas scrollPoint:anchor];
    self.canvas.needsDisplay = YES;
    [self.canvas.window invalidateCursorRectsForView:self.canvas];
}
@end
