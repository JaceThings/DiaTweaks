#import "Patches/SidebarLibrary/Library.h"
@interface HoverWindow : NSWindow
@property NSPoint pointer;
@end
@implementation HoverWindow
- (BOOL)isKeyWindow { return YES; }
- (NSPoint)mouseLocationOutsideOfEventStream { return self.pointer; }
@end
@interface HoverDocument : NSView @end
@implementation HoverDocument
- (BOOL)isFlipped { return YES; }
@end
@interface DPLibraryMediaView (HoverFixture)
- (void)setHover:(BOOL)value;
@end
int main(void) { @autoreleasepool {
 [NSApplication sharedApplication];
 HoverWindow *window=[[HoverWindow alloc] initWithContentRect:NSMakeRect(0,0,250,180) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
 NSScrollView *scroll=[[NSClassFromString(@"DPLibraryScrollView") alloc] initWithFrame:window.contentView.bounds];
 HoverDocument *document=[[HoverDocument alloc] initWithFrame:NSMakeRect(0,0,230,600)];
 scroll.documentView=document; [window.contentView addSubview:scroll];
 NSMutableArray<DPLibraryMediaView *> *tiles=NSMutableArray.new;
 for(NSUInteger i=0;i<3;i++) { DPLibraryMediaView *tile=[[DPLibraryMediaView alloc] initWithFrame:NSMakeRect(0,i*160,220,150)]; [document addSubview:tile]; [tiles addObject:tile]; }
 window.pointer=[tiles[0] convertPoint:NSMakePoint(50,50) toView:nil];
 [scroll.contentView scrollToPoint:NSZeroPoint]; [scroll reflectScrolledClipView:scroll.contentView];
 DPLibraryReconcileHover(document);
 NSCAssert(tiles[0].hovered && !tiles[1].hovered && !tiles[2].hovered,@"only tile under pointer is hovered");
 for(NSUInteger pass=0;pass<60;pass++) {
  for(DPLibraryMediaView *tile in tiles) [tile setHover:YES]; // stale tracking events
  [scroll.contentView scrollToPoint:NSMakePoint(0,(pass%3)*160)];
  [scroll reflectScrolledClipView:scroll.contentView];
  NSUInteger count=0;for(DPLibraryMediaView *tile in tiles)if(tile.hovered)count++;
  NSCAssert(count==1,@"stationary-pointer scrolling clears prior and recycled item highlights");
 }
 window.pointer=NSMakePoint(-100,-100);DPLibraryReconcileHover(document);
 for(DPLibraryMediaView *tile in tiles)NSCAssert(!tile.hovered,@"moving outside clears every hover");
 puts("PASS: 60 stationary-pointer scroll/reuse cycles retain exactly one hover; leaving clears all");
} }
