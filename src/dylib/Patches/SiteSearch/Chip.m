#import "SiteSearch.h"

static char DPChipKey, DPPaddingKey;

// "Search Amazon" at the start of the field, the text moved over to make room for it.
void DPShowChip(NSTextView *text, DPSite *site) {
    NSTextField *chip = DPGet(text, &DPChipKey);
    if (!site) {
        [chip removeFromSuperview];
        DPSet(text, &DPChipKey, nil);
        NSNumber *padding = DPGet(text, &DPPaddingKey);
        if (padding) text.textContainer.lineFragmentPadding = padding.doubleValue;
        DPSet(text, &DPPaddingKey, nil);
        return;
    }
    if (!chip) {
        chip = [NSTextField labelWithString:@""];
        chip.wantsLayer = YES;
        chip.layer.cornerRadius = 5;
        chip.layer.backgroundColor = [NSColor.controlAccentColor colorWithAlphaComponent:0.18].CGColor;
        chip.textColor = NSColor.controlAccentColor;
        chip.alignment = NSTextAlignmentCenter;
        DPSet(text, &DPChipKey, chip);
        DPSet(text, &DPPaddingKey, @(text.textContainer.lineFragmentPadding));
    }
    chip.font = [NSFont systemFontOfSize:(text.font.pointSize ?: 14) - 1 weight:NSFontWeightMedium];
    chip.stringValue = [NSString stringWithFormat:@"Search %@", site.name];
    [chip sizeToFit];
    NSSize size = NSMakeSize(chip.frame.size.width + 14, chip.frame.size.height + 4);
    NSView *host = text.enclosingScrollView ?: text;
    NSView *parent = host.superview;
    NSRect field = host.frame;
    chip.frame = NSMakeRect(NSMinX(field), NSMidY(field) - size.height / 2, size.width, size.height);
    if (chip.superview != parent) [parent addSubview:chip positioned:NSWindowAbove relativeTo:host];
    text.textContainer.lineFragmentPadding = [DPGet(text, &DPPaddingKey) doubleValue] + size.width + 6;
}
