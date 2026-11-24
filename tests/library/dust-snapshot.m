#import "Patches/SidebarLibrary/Dust.h"
@interface DustSource : NSView
@property BOOL sourceFlipped;
@end
@implementation DustSource
- (BOOL)isFlipped { return self.sourceFlipped; }
- (void)drawRect:(NSRect)r {
 [NSColor.redColor setFill];NSRectFill(NSMakeRect(0,self.sourceFlipped?0:32,64,32));
 [NSColor.blueColor setFill];NSRectFill(NSMakeRect(0,self.sourceFlipped?32:0,64,32));
}
@end
int main(void){ @autoreleasepool {
 [NSApplication sharedApplication];
 for(NSNumber *flipped in @[@NO,@YES]) {
  NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,128,160) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
  DustSource *source=[[DustSource alloc] initWithFrame:NSMakeRect(0,0,64,64)];source.sourceFlipped=flipped.boolValue;[window.contentView addSubview:source];
  NSBitmapImageRep *snapshot=[source bitmapImageRepForCachingDisplayInRect:source.bounds];[source cacheDisplayInRect:source.bounds toBitmapImageRep:snapshot];
  NSImage *image=[[NSImage alloc] initWithSize:source.bounds.size];[image addRepresentation:snapshot];
  DPLibraryDust *dust=[[DPLibraryDust alloc] initWithFrame:NSMakeRect(64,0,64,160)];dust.image=image;dust.imageRect=NSMakeRect(0,96,64,64);dust.started=CACurrentMediaTime()+100;[window.contentView addSubview:dust];
  NSBitmapImageRep *result=[window.contentView bitmapImageRepForCachingDisplayInRect:window.contentView.bounds];[window.contentView cacheDisplayInRect:window.contentView.bounds toBitmapImageRep:result];
  CGFloat scaleX=(CGFloat)result.pixelsWide/NSWidth(window.contentView.bounds),scaleY=(CGFloat)result.pixelsHigh/NSHeight(window.contentView.bounds);
  for(NSNumber *sampleY in @[@106,@150]) {
   NSColor *a=[[result colorAtX:10*scaleX y:sampleY.integerValue*scaleY] colorUsingColorSpace:NSColorSpace.sRGBColorSpace],*b=[[result colorAtX:74*scaleX y:sampleY.integerValue*scaleY] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
   printf("sourceFlipped=%d y=%ld source=%.1f/%.1f dust=%.1f/%.1f\n",flipped.boolValue,sampleY.integerValue,a.redComponent,a.blueComponent,b.redComponent,b.blueComponent);
   NSCAssert(MAX(a.redComponent,a.blueComponent)>.7 && fabs(a.redComponent-a.blueComponent)>.4,@"fixture actually paints the colored source");
   NSCAssert(fabs(a.redComponent-b.redComponent)<.1 && fabs(a.blueComponent-b.blueComponent)<.1,@"initial dust snapshot matches source orientation");
  }
 }
 puts("PASS: initial snapshots preserve both flipped and unflipped AppKit source orientation");
} }
