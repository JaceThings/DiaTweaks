#import "Patches/Easels/ToolButton.h"
#import <QuartzCore/QuartzCore.h>
NSColor *DPEaselAccent(NSView *view) { return NSColor.systemBlueColor; }
@interface HoverWindow : NSWindow @end
@implementation HoverWindow
- (BOOL)isKeyWindow { return YES; }
- (NSPoint)mouseLocationOutsideOfEventStream { return NSMakePoint(18,18); }
@end
@interface IconCell : NSButtonCell
@property CGAffineTransform drawTransform;
@property NSUInteger draws;
@end
@implementation IconCell
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
    self.drawTransform=CGContextGetCTM(NSGraphicsContext.currentContext.CGContext); self.draws++;
}
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window=[[HoverWindow alloc] initWithContentRect:NSMakeRect(0,0,36,36) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    DPEaselToolButton *button=[[DPEaselToolButton alloc] initWithFrame:NSMakeRect(0,0,36,36)];
    IconCell *cell=IconCell.new; button.cell=cell; [window.contentView addSubview:button];
    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(36,36)]; [image lockFocus];
    for(NSString *letter in @[@"",@"I",@"T",@"O",@"R",@"A",@"P"]) for(NSUInteger state=0;state<2;state++) {
        button.letter=letter; button.state=state; button.pointerInside=NO; [button drawRect:button.bounds];
        CGAffineTransform normal=cell.drawTransform;
        button.pointerInside=YES; [button drawRect:button.bounds];
        NSCAssert(CGAffineTransformEqualToTransform(normal,cell.drawTransform),@"hover box and shortcut cannot displace toolbar icons");
    }
    [image unlockFocus]; NSCAssert(cell.draws==28,@"all selected/unselected tools render through the native cell");
    puts("PASS: all toolbar icons retain their native drawing position on hover, selected or unselected");
} }
