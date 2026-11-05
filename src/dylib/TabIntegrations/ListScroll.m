#import "ListRows.h"

@interface DPIntegrationListDocument : NSView
@end
@implementation DPIntegrationListDocument
- (BOOL)isFlipped { return YES; }
@end

NSSize DPIntegrationListFitContent(NSView *view, CGFloat height, CGFloat maximumHeight) {
    CGFloat limit = maximumHeight > 0 ? MAX(100, maximumHeight) : height;
    if (height <= limit) return NSMakeSize(280, height);
    DPIntegrationListDocument *document = [[DPIntegrationListDocument alloc] initWithFrame:NSMakeRect(0, 0, 280, height - 38)];
    for (NSView *child in view.subviews.copy) if (child.frame.origin.y >= 38) {
        [child setFrameOrigin:NSMakePoint(child.frame.origin.x, child.frame.origin.y - 38)];
        [document addSubview:child];
    }
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 38, 280, limit - 38)];
    scroll.borderType = NSNoBorder;
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    scroll.documentView = document;
    [view addSubview:scroll];
    return NSMakeSize(280, limit);
}
