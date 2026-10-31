#import "SidebarToolbar.h"

// Docked: navigation buttons beside the traffic lights, anything else below, then the address.
void DPPlaceDocked(NSView *bar, NSView *row, NSView *field) {
    NSView *sidebar = bar.superview, *address = DPBarAddress(bar);
    CGFloat height = NSHeight(row.bounds);
    NSRect (^fromTop)(NSRect) = ^NSRect(NSRect r) {
        if (!row.isFlipped) r.origin.y = height - NSMaxY(r);
        return r;
    };
    NSRect (^inRow)(NSView *) = ^NSRect(NSView *v) { return fromTop([row convertRect:v.bounds fromView:v]); };

    // Between the traffic lights and the header's next visible control, which takes the profile's place.
    CGFloat headerHeight = NSHeight(DPHeaderRow(sidebar));
    CGFloat left = DPDockInset, right = NSWidth(row.bounds) - 4;
    NSView *lights = DPLights(DPSidebarHeader(sidebar));
    if (lights) left = NSMaxX(inRow(lights)) + 2;
    for (NSView *control in lights.superview.subviews) {
        if (control == lights || control.hidden) continue;
        NSRect frame = inRow(control);
        if (NSMinX(frame) > left) right = MIN(right, NSMinX(frame) - 2);
    }
    // The sidebar toggle follows the traffic lights; back, forward and reload sit at the right edge.
    // Buttons shrink from 28pt to 22pt to fit; below that they run past the edge, and whatever doesn't fit fades out.
    NSArray<NSView *> *navigation = DPBarItems(bar, YES);
    // Even sizes keep the icons on whole pixels as the sidebar is resized.
    const CGFloat size = MIN(28, MAX(22, floor((right - left) / MAX(navigation.count, 1) / 2) * 2)), y = round((headerHeight - size) / 2);
    CGFloat next = left;
    NSMutableArray<NSView *> *group = [NSMutableArray new];
    for (NSView *item in navigation) {
        if (!DPIsSidebarToggle(item)) {
            [group addObject:item];
            continue;
        }
        item.frame = fromTop(NSMakeRect(left, y, size, size));
        next = left + size;
        // Centred on whole pixels: centring an odd-sized glyph in the button blurs it on 1x displays.
        for (NSImageView *image in item.subviews) {
            if (![image isKindOfClass:NSImageView.class]) continue;
            NSSize glyph = image.intrinsicContentSize;
            NSRect frame = [item backingAlignedRect:NSMakeRect((size - glyph.width) / 2, (size - glyph.height) / 2, glyph.width, glyph.height) options:NSAlignAllEdgesNearest];
            if (!NSEqualRects(image.frame, frame)) image.frame = frame;
        }
    }
    CGFloat x = MAX(next, right - group.count * size);
    for (NSView *item in group) {
        item.frame = fromTop(NSMakeRect(x, y, size, size));
        x += size;
        DPFadeUnlessFits(item, x <= right + 0.5);
    }

    NSArray<NSView *> *extras = DPBarItems(bar, NO);
    const CGFloat below = headerHeight + DPHeaderGap(sidebar);
    for (NSView *item in extras) {
        NSRect frame = item.frame;
        frame.size.height = MIN(NSHeight(frame), DPDockRowHeight);
        frame.origin.y = below + round((DPDockRowHeight - NSHeight(frame)) / 2);
        item.frame = fromTop(frame);
    }
    CGFloat top = below + (extras.count ? DPDockRowHeight : 0);
    NSRect box = NSMakeRect(DPDockInset, top, NSWidth(row.bounds) - 2 * DPDockInset, DPDockFieldHeight);
    field.frame = [bar convertRect:fromTop(box) fromView:row];
    NSView *button = DPExtensionsButton(bar);
    CGFloat width = button ? 26 : 0;
    if (button) button.frame = [bar convertRect:fromTop(NSMakeRect(NSMaxX(box) - width - 2, top + (DPDockFieldHeight - 24) / 2, width, 24)) fromView:row];
    NSRect text = NSInsetRect(box, 2, 2);
    text.size.width -= width;
    address.frame = fromTop(text);
    DPArrangeAddress(address, YES);
}
