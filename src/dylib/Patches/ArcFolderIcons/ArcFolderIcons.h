#import "StdPatch/StdPatch.h"

typedef NS_ENUM(NSInteger, DPFolderLook) {
    DPFolderClosed,
    DPFolderOpen,
    DPFolderPeeked,  // Collapsed with its active tab left showing, which Arc marks with three dots.
};

NSImage *DPFolderImage(DPFolderLook look, NSColor *tint, BOOL dark);  // Cached per state and tint, so the same folder is the same image.
BOOL DPIsFolderImage(NSImage *image);
NSColor *DPSidebarTint(NSWindow *window, BOOL *dark);  // dark: whether the sidebar is in dark appearance.
