#import "Patches/SidebarLibrary/Library.h"
DPPatch DPSidebarLibrary;
@implementation DPLibraryController @end
void DPLibraryEndInteractiveLayout(DPLibraryController *controller) { controller.interacting = NO; }
void DPLibraryUpdateHosts(DPLibraryController *controller) {}
void DPLibraryUnmount(DPLibraryController *controller) { [controller.view removeFromSuperview]; controller.expanded = NO; }
@interface LibraryFocusView : NSView @end
@implementation LibraryFocusView
- (BOOL)acceptsFirstResponder { return YES; }
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    LibraryFocusView *original = [LibraryFocusView new], *library = [LibraryFocusView new];
    [window.contentView addSubview:original]; [window.contentView addSubview:library];
    [window makeFirstResponder:library];
    DPLibraryController *controller = [DPLibraryController new]; controller.window = window;
    controller.view = library; controller.expanded = YES; controller.previousResponder = original;
    DPLibraryAnimate(controller,NO);
    NSCAssert(!controller.expanded && !controller.view.superview,@"immediate close removes Library");
    NSCAssert(window.firstResponder == original && !controller.previousResponder,@"immediate close restores keyboard focus");
    [window.contentView addSubview:library]; [window makeFirstResponder:library];
    controller.expanded=YES; controller.previousResponder=original; [original removeFromSuperview];
    DPLibraryAnimate(controller,NO);
    NSCAssert(window.firstResponder!=original && !controller.previousResponder,@"a page replaced while Library closes is never restored as a detached first responder");
    NSWindow *other=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    [other.contentView addSubview:original]; [window.contentView addSubview:library]; [window makeFirstResponder:library];
    controller.expanded=YES; controller.previousResponder=original; DPLibraryAnimate(controller,NO);
    NSCAssert(window.firstResponder!=original && !controller.previousResponder,@"a responder moved to another window is not focused by the old window");
    puts("PASS: immediate close restores focus and clears previous responder");
} }
