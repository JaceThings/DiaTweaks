#import "TaskTable.h"
#import "TaskView.h"
@implementation DPTaskTable
- (void)mouseDown:(NSEvent *)event {
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil]; NSInteger row=[self rowAtPoint:point];
    if(row>=0) {
        DPTaskCell *cell=(id)[self viewAtColumn:0 row:row makeIfNecessary:YES];
        NSPoint local=[cell convertPoint:event.locationInWindow fromView:nil];
        if(local.x>=NSMaxX(cell.check.frame)) { [cell startEditing:self]; return; }
    }
    [super mouseDown:event];
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSInteger row=[self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    return row<0 ? nil : [[self viewAtColumn:0 row:row makeIfNecessary:YES] menuForEvent:event];
}
@end
