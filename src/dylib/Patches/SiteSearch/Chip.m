#import "SiteSearch.h"

static char DPChipKey, DPPaddingKey;

#define DPDiaSuggestionsView "_TtC15BoostCommandBar15SuggestionsView"
#define DPDiaIconContainer   "_TtC15BoostCommandBar17IconContainerView"

// The site's icon and name in a capsule tinted like the bar's own controls, redrawn when the appearance changes.
@interface DPSiteChip : NSView
@property(strong) NSImageView *icon;
@property(strong) NSTextField *label;
@end

@implementation DPSiteChip
- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    _icon = [NSImageView new];
    _icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    _label = [NSTextField labelWithString:@""];
    _label.textColor = NSColor.labelColor;
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_icon];
    [self addSubview:_label];
    return self;
}
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:0.08].CGColor;
        self.layer.borderColor = [NSColor.labelColor colorWithAlphaComponent:0.1].CGColor;
    }];
    self.layer.borderWidth = 0.5;
    self.layer.cornerRadius = NSHeight(self.bounds) / 2;
}
- (NSSize)fitWithFont:(NSFont *)font {
    self.label.font = [NSFont systemFontOfSize:font.pointSize - 1 weight:NSFontWeightMedium];
    [self.label sizeToFit];
    CGFloat height = ceil(font.pointSize + 9), side = round(font.pointSize);
    NSSize text = self.label.frame.size;
    self.icon.frame = NSMakeRect(7, (height - side) / 2, side, side);
    self.label.frame = NSMakeRect(NSMaxX(self.icon.frame) + 5, round((height - text.height) / 2), text.width, text.height);
    return NSMakeSize(ceil(NSMaxX(self.label.frame) + 9), height);
}
@end

// The site's icon from what Dia shows, else a globe. Dia already has it, so nothing is fetched. Symbols such as Dia's own
// globe are templates; a site's icon is a picture, often only on suggestions for its pages, not the site itself.
static NSImage *DPIconFor(NSTextView *text, DPSite *site) {
    NSView *input = text;
    while (input && !DPIsKind(input, DPDiaCommandBarInput)) input = input.superview;
    NSImageView *field = (NSImageView *)DPFindView(DPFindView(input, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaIconContainer); }), ^BOOL(NSView *view) {
        return [view isKindOfClass:NSImageView.class];
    });
    if (field.image && !field.image.isTemplate) return field.image;
    NSTableView *table = (NSTableView *)DPFindView(text.window.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSTableView.class] && DPIsKind(((NSTableView *)view).delegate, DPDiaSuggestionsView);
    });
    for (NSInteger row = 0; row < table.numberOfRows; row++) {
        NSView *view = [table rowViewAtRow:row makeIfNecessary:YES];
        BOOL names = DPFindView(view, ^BOOL(NSView *sub) {
            return [sub isKindOfClass:NSTextField.class] && [((NSTextField *)sub).stringValue.lowercaseString containsString:site.host];
        }) != nil;
        NSImageView *icon = names ? (NSImageView *)DPFindView(view, ^BOOL(NSView *sub) {
            return [sub isKindOfClass:NSImageView.class] && ((NSImageView *)sub).image && !((NSImageView *)sub).image.isTemplate;
        }) : nil;
        if (icon) return icon.image;
    }
    return [NSImage imageWithSystemSymbolName:@"globe" accessibilityDescription:nil];
}

// The site's chip at the start of the field, the text moved over to make room for it.
void DPShowChip(NSTextView *text, DPSite *site) {
    DPSiteChip *chip = DPGet(text, &DPChipKey);
    DPSetPlaceholder(text, site);
    if (!site) {
        [chip removeFromSuperview];
        DPSet(text, &DPChipKey, nil);
        NSNumber *padding = DPGet(text, &DPPaddingKey);
        if (padding) text.textContainer.lineFragmentPadding = padding.doubleValue;
        DPSet(text, &DPPaddingKey, nil);
        return;
    }
    if (!chip) {
        chip = [DPSiteChip new];
        DPSet(text, &DPChipKey, chip);
        DPSet(text, &DPPaddingKey, @(text.textContainer.lineFragmentPadding));
    }
    chip.label.stringValue = site.name;
    chip.icon.image = DPIconFor(text, site);
    NSFont *font = text.font ?: [NSFont systemFontOfSize:14];
    NSSize size = [chip fitWithFont:font];
    // Level with the first line of text, which sits higher than the middle of a field that grows.
    NSView *host = text.enclosingScrollView ?: text;
    CGFloat line = font.ascender - font.descender + font.leading;
    NSPoint middle = [text convertPoint:NSMakePoint(0, text.textContainerInset.height + line / 2) toView:host.superview];
    chip.frame = NSMakeRect(NSMinX(host.frame), round(middle.y - size.height / 2), size.width, size.height);
    if (chip.superview != host.superview) [host.superview addSubview:chip positioned:NSWindowAbove relativeTo:host];
    text.textContainer.lineFragmentPadding = [DPGet(text, &DPPaddingKey) doubleValue] + size.width + 6;
}


// The Return button names where Return goes, "Google" for words; with a site chosen, it goes there.
void DPShowReturnTarget(NSTextView *text, DPSite *site) {
    NSView *bar = text;
    while (bar && !DPIsKind(bar, DPDiaCommandBar)) bar = bar.superview;
    NSView *button = DPFindView(bar, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaCommandBarButton) && DPFindView(view, ^BOOL(NSView *sub) { return [sub isKindOfClass:NSImageView.class] && DPHasLabel(sub, @"Return"); });
    });
    NSTextField *label = (NSTextField *)DPFindView(button, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextField.class]; });
    if (site && label && ![label.stringValue isEqual:site.name]) label.stringValue = site.name;
}
