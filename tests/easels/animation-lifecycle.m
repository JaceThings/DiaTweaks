#import "Patches/Easels/Canvas.h"
#import "Patches/Easels/Animation.h"
#import <objc/runtime.h>
#import <stdio.h>
DPPatch DPEasels={.on=YES};
NSString *DPAppSupport(NSString *path) { return NSTemporaryDirectory(); }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.controlAccentColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static NSMutableArray *callbacks;
static BOOL request(id object,SEL selector,NSUInteger frame,void (^completion)(NSImage *,NSTimeInterval,NSUInteger)) {
    [callbacks addObject:[completion copy]]; return YES;
}
@interface VisibleFixtureWindow : NSWindow @end
@implementation VisibleFixtureWindow
- (NSWindowOcclusionState)occlusionState { return NSWindowOcclusionStateVisible; }
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; callbacks=NSMutableArray.new;
    Method method=class_getInstanceMethod(DPEaselFrameSource.class,@selector(request:completion:)); IMP original=method_setImplementation(method,(IMP)request);
    DPEaselCanvas *canvas=[[DPEaselCanvas alloc] initWithFrame:NSMakeRect(0,0,400,400)];
    canvas.document=[DPEaselDocument documentWithSize:NSMakeSize(400,600)];
    NSString *asset=NSUUID.UUID.UUIDString;
    [canvas.document replaceObjects:@[@{@"id":NSUUID.UUID.UUIDString,@"type":@"image",@"asset":asset,@"animated":@YES,@"rect":@[@40,@50,@60,@60],@"order":@1,@"z":@1}] action:@"Fixture"];
    VisibleFixtureWindow *window=[[VisibleFixtureWindow alloc] initWithContentRect:NSMakeRect(0,0,400,400) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO; window.contentView=canvas;
    [canvas animateVisibleImages]; NSCAssert(callbacks.count==1 && canvas.players.count==1,@"visible animation queues one bounded frame request");
    void (^valid)(NSImage *,NSTimeInterval,NSUInteger)=callbacks.lastObject;
    NSImage *frame=[[NSImage alloc] initWithSize:NSMakeSize(2,2)]; valid(frame,.1,2);
    NSCAssert([canvas.images objectForKey:asset]==frame,@"current visible player accepts its completed frame");
    [canvas stopImageAnimations]; [canvas.images removeAllObjects];
    [canvas animateVisibleImages]; NSCAssert(callbacks.count==2,@"returning to the board creates a fresh playback generation");
    void (^late)(NSImage *,NSTimeInterval,NSUInteger)=callbacks.lastObject;
    [canvas stopImageAnimations]; late(frame,.1,2);
    NSCAssert(!canvas.players.count && !canvas.animationClock && ![canvas.images objectForKey:asset],@"late callback from a released player cannot restore offscreen frames or an idle animation clock");
    method_setImplementation(method,original); [canvas removeFromSuperview]; [window close];
    puts("PASS: visible animation delivery, fresh player generations and late frame rejection after stop/teardown");
} }
