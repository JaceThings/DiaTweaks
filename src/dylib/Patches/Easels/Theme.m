#import "Canvas.h"
extern NSColor *DPLibraryAccentColor(NSWindow *window);
NSColor *DPEaselAccent(NSView *view) { return view.window ? DPLibraryAccentColor(view.window) : NSColor.controlAccentColor; }
void DPEaselStyleColorWell(NSVisualEffectView *view) {
    // Match the native popover material used by the adjacent tool palette.
    view.layer.backgroundColor=nil; view.layer.borderColor=nil; view.layer.borderWidth=0;
}
