#import "SidebarToolbar.h"

static char DPGravityKey;

NSStackView *DPDownloadsHome(NSView *downloads) {
    return [DPGet(downloads, &DPGravityKey) firstObject];
}

// Downloads moves from the header to the footer, in place of the library.
void DPArrangeFooter(NSView *sidebar, NSView *header, BOOL docked) {
    NSView *footer = DPSubview(sidebar, DPDiaSidebarFooter);
    NSView *library = DPFindView(footer, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaLibraryButton); });
    BOOL (^isDownloads)(NSView *) = ^BOOL(NSView *v) { return DPIsKind(v, DPDiaDownloadsButton); };
    NSView *downloads = DPFindView(header, isDownloads) ?: DPFindView(footer, isDownloads);
    if (!footer || !library || !downloads) return;
    DPSetHiddenByUs(library, docked);
    if (docked && downloads.superview != footer) {
        NSStackView *stack = [downloads.superview isKindOfClass:NSStackView.class] ? (NSStackView *)downloads.superview : nil;
        for (NSStackViewGravity gravity = NSStackViewGravityLeading; gravity <= NSStackViewGravityTrailing; gravity++)
            if ([[stack viewsInGravity:gravity] containsObject:downloads]) DPSet(downloads, &DPGravityKey, @[stack, @(gravity)]);
        [stack removeView:downloads];
        [footer addSubview:downloads];
    } else if (!docked && downloads.superview == footer) {
        NSArray *home = DPGet(downloads, &DPGravityKey);
        DPSet(downloads, &DPGravityKey, nil);
        [downloads removeFromSuperview];
        [(NSStackView *)home.firstObject addView:downloads inGravity:[home.lastObject integerValue]];
    }
    if (docked) {
        NSSize size = downloads.frame.size;
        downloads.frame = NSMakeRect(round(NSMidX(library.frame) - size.width / 2), round(NSMidY(library.frame) - size.height / 2), size.width, size.height);
    }
}

// Dia removes downloads from the stack it was taken out of, which NSStackView asserts against; the removal is done.
void DPForgetDownloadsHome(NSView *downloads) {
    DPSet(downloads, &DPGravityKey, nil);
}
