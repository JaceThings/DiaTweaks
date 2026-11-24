#import "Library.h"
NSImage *DPLibraryEntryImage(void) {
    // A small stack reads as a collection without the detail of book spines.
    // Preserve the original Library mark if the preferred symbol is unavailable.
    return [NSImage imageWithSystemSymbolName:@"rectangle.stack" accessibilityDescription:nil] ?:
        [NSImage imageWithSystemSymbolName:@"books.vertical" accessibilityDescription:nil];
}
