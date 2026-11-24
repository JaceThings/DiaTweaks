#import "Library.h"
#import <objc/message.h>
BOOL DPLibraryPointerInside(NSView *view) {
    if(!view.window.isKeyWindow || view.isHiddenOrHasHiddenAncestor) return NO;
    NSPoint point=[view convertPoint:view.window.mouseLocationOutsideOfEventStream fromView:nil];
    return NSMouseInRect(point,NSIntersectionRect(view.bounds,view.visibleRect),view.isFlipped);
}
void DPLibraryReconcileHover(NSView *root) {
    SEL selector=NSSelectorFromString(@"dpLibraryUpdatePointerHover");
    if([root respondsToSelector:selector]) ((void(*)(id,SEL))objc_msgSend)(root,selector);
    for(NSView *child in root.subviews) DPLibraryReconcileHover(child);
}
// Scrolling can replace tracking areas without delivering their old exit event.
// Reconcile visible/reused views from the stationary pointer after each native
// clip update. There is no timer or event interception outside Library.
@interface DPLibraryScrollView : NSScrollView @end
@implementation DPLibraryScrollView
- (void)reflectScrolledClipView:(NSClipView *)clip {
    [super reflectScrolledClipView:clip];
    if(clip==self.contentView) DPLibraryReconcileHover(self.documentView);
}
@end
