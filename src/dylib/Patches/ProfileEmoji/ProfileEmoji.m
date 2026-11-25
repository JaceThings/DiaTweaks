#import "StdPatch/StdPatch.h"

extern DPPatch DPProfileEmoji, DPProfileEmojiCurrentOnly;

static NSString *const DPEmojisKey = @"profileEmojis";
static const CGFloat DPSidebarEmojiSize = 13.5, DPSidebarEmojiWidth = 16, DPSidebarDotWidth = 6, DPSidebarGap = 10;
static NSHashTable<NSViewController *> *DPProfilePanes;
static char DPLabelKey, DPRowKey, DPNativeFrameKey, DPDotShiftedKey;

static NSString *DPEmoji(NSString *spaceID, BOOL active) {
    if (!DPProfileEmoji.on || !spaceID || (DPProfileEmojiCurrentOnly.on && !active)) return nil;
    return [DPSettingsDefaults() dictionaryForKey:DPEmojisKey][spaceID];
}

static NSString *DPSpaceIDOf(NSView *view, NSDictionary *views) {
    for (id key in views) if (views[key] == view) return [key description];
    return nil;
}

static BOOL DPAnyEmoji(NSDictionary *views, NSDictionary *emojis) {
    for (id key in views) {
        if (DPProfileEmojiCurrentOnly.on && ![DPSwiftValue(views[key], @"isSelected") boolValue]) continue;
        if (emojis[[key description]]) return YES;
    }
    return NO;
}

static void DPShowEmoji(NSView *host, NSView *dot, NSString *emoji, CGFloat size, CGFloat alpha) {
    NSTextField *label = DPGet(host, &DPLabelKey);
    if (!emoji) {
        if (!label) return;
        if (dot.hidden) dot.hidden = NO;
        [label removeFromSuperview];
        DPSet(host, &DPLabelKey, nil);
        return;
    }
    if (!dot.hidden) dot.hidden = YES;
    BOOL resized = !label;
    if (!label) {
        label = [NSTextField labelWithString:@""];
        label.translatesAutoresizingMaskIntoConstraints = YES;
        label.alignment = NSTextAlignmentCenter;
        [host addSubview:label];
        DPSet(host, &DPLabelKey, label);
    }
    if (![label.stringValue isEqual:emoji]) {
        label.stringValue = emoji;
        resized = YES;
    }
    if (fabs(label.font.pointSize - size) > 0.01) {
        label.font = [NSFont systemFontOfSize:size];
        resized = YES;
    }
    if (fabs(label.alphaValue - alpha) > 0.001) label.alphaValue = alpha;
    NSSize fit = (resized || NSWidth(label.frame) <= 0 || NSHeight(label.frame) <= 0)
        ? [label sizeThatFits:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)]
        : label.frame.size;
    if (fit.width <= 0 || fit.height <= 0) {
        [label sizeToFit];
        fit = label.frame.size;
    }
    NSRect target = (NSRect){ { round(NSMidX(host.bounds) - fit.width / 2), round(NSMidY(host.bounds) - fit.height / 2) }, fit };
    if (!NSEqualRects(label.frame, target)) label.frame = target;
}

static void DPShowSidebarItem(NSView *item) {
    NSTextField *existing = DPGet(item, &DPLabelKey);
    BOOL shifted = [DPGet(item, &DPDotShiftedKey) boolValue];
    if (!DPProfileEmoji.on && !existing && !shifted) return;
    NSDictionary *views = DPSwiftValue(item.superview, @"itemViews");
    NSDictionary *emojis = DPProfileEmoji.on ? [DPSettingsDefaults() dictionaryForKey:DPEmojisKey] : nil;
    BOOL selected = [DPSwiftValue(item, @"isSelected") boolValue];
    NSString *emoji = DPEmoji(DPSpaceIDOf(item, views), selected);
    BOOL any = emoji != nil || (emojis.count && DPAnyEmoji(views, emojis));
    if (!existing && !any && !shifted) return;
    NSView *dot = DPSwiftValue(item, @"$__lazy_storage_$_dotView");
    if (dot && !emoji) {
        NSPoint origin = NSMakePoint(round(NSMidX(item.bounds) - NSWidth(dot.frame) / 2), NSMinY(dot.frame));
        if (!NSEqualPoints(dot.frame.origin, origin)) [dot setFrameOrigin:origin];
        DPSet(item, &DPDotShiftedKey, any ? @YES : nil);
    }
    DPShowEmoji(item, dot, emoji, DPSidebarEmojiSize, selected ? 1 : 0.45);
}

static CGFloat DPSidebarItemWidth(NSView *item, NSDictionary *views, NSDictionary *emojis) {
    NSString *spaceID = DPSpaceIDOf(item, views);
    BOOL showEmoji = spaceID && emojis[spaceID] && (!DPProfileEmojiCurrentOnly.on || [DPSwiftValue(item, @"isSelected") boolValue]);
    return (showEmoji ? DPSidebarEmojiWidth : DPSidebarDotWidth) + DPSidebarGap;
}

static NSComparisonResult DPSidebarCompareItems(NSView *a, NSView *b) {
    NSValue *va = DPGet(a, &DPNativeFrameKey), *vb = DPGet(b, &DPNativeFrameKey);
    CGFloat left = va ? NSMidX(va.rectValue) : NSMidX(a.frame);
    CGFloat right = vb ? NSMidX(vb.rectValue) : NSMidX(b.frame);
    if (left < right) return NSOrderedAscending;
    return left > right ? NSOrderedDescending : NSOrderedSame;
}

static void DPLayoutSidebarRow(NSView *switcher) {
    if (!switcher) return;
    NSDictionary *views = DPSwiftValue(switcher, @"itemViews");
    if (!views.count) return;
    NSDictionary *emojis = DPProfileEmoji.on ? [DPSettingsDefaults() dictionaryForKey:DPEmojisKey] : nil;
    BOOL adjusted = NO;
    if (!emojis.count || !DPAnyEmoji(views, emojis)) {
        for (NSView *item in views.allValues) {
            NSValue *native = DPGet(item, &DPNativeFrameKey);
            if (!native || NSWidth(item.frame) < DPSidebarDotWidth + DPSidebarGap) continue;
            NSRect target = native.rectValue;
            if (!NSEqualRects(item.frame, target)) {
                if (!adjusted && !DPMayAdjust(switcher)) return;
                adjusted = YES;
                item.frame = target;
            }
        }
        return;
    }
    NSMutableArray<NSView *> *row = [NSMutableArray arrayWithArray:views.allValues];
    [row sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) { return DPSidebarCompareItems(a, b); }];
    CGFloat total = 0;
    for (NSView *item in row) total += DPSidebarItemWidth(item, views, emojis);
    CGFloat x = round(NSMidX(switcher.bounds) - total / 2);
    for (NSView *item in row) {
        CGFloat width = DPSidebarItemWidth(item, views, emojis);
        NSRect target = NSMakeRect(x, NSMinY(item.frame), width, NSHeight(item.frame));
        if (!NSEqualRects(item.frame, target)) {
            if (!adjusted && !DPMayAdjust(switcher)) return;
            adjusted = YES;
            item.frame = target;
        }
        x += width;
    }
}

static void DPSidebarSwitcher_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarSwitcher_layout, self);
    DPLayoutSidebarRow(self);
}

static void DPSidebarItem_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    BOOL native = NSWidth(frame) > 0 && NSWidth(frame) < DPSidebarDotWidth + DPSidebarGap;
    if (native) DPSet(self, &DPNativeFrameKey, [NSValue valueWithRect:frame]);
    DPCallOriginal(DPSidebarItem_setFrame, self, frame);
    if (native && DPProfileEmoji.on) DPLayoutSidebarRow(self.superview);
}

static void DPSidebarItem_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_layout, self);
    DPShowSidebarItem(self);
}

static void DPUpdateEmojiLayer(NSView *view, BOOL active, NSString *emoji, BOOL relayoutParent) {
    NSTextField *label = DPGet(view, &DPLabelKey);
    if ((emoji != nil) != (label != nil)) {
        __weak NSView *weakSelf = view;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (relayoutParent) weakSelf.superview.needsLayout = YES;
            weakSelf.needsLayout = YES;
        });
        return;
    }
    if (!label) return;
    CGFloat alpha = active ? 1 : 0.45;
    if (fabs(label.alphaValue - alpha) > 0.001) label.alphaValue = alpha;
}

static void DPSidebarItem_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_updateLayer, self);
    if (!DPProfileEmoji.on && !DPGet(self, &DPLabelKey)) return;
    BOOL selected = [DPSwiftValue(self, @"isSelected") boolValue];
    NSString *emoji = DPEmoji(DPSpaceIDOf(self, DPSwiftValue(self.superview, @"itemViews")), selected);
    DPUpdateEmojiLayer(self, selected, emoji, YES);
}

static BOOL DPTopDotFocused(NSView *dot, NSString *spaceID) {
    id focusedID = DPSwiftValue(dot.superview, @"focusedSpaceID");
    if (focusedID) return [[focusedID description] isEqual:spaceID];
    return [DPSwiftValue(dot, @"isSelected") boolValue];
}

static void DPTopDot_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTopDot_layout, self);
    NSView *label = DPGet(self, &DPLabelKey);
    if (!DPProfileEmoji.on && !label) return;
    NSView *indicator = self.superview, *dot = nil;
    for (NSView *sub in self.subviews) if (sub != label) { dot = sub; break; }
    NSString *spaceID = DPSpaceIDOf(self, DPSwiftValue(indicator, @"dotViews"));
    BOOL focused = DPTopDotFocused(self, spaceID);
    DPShowEmoji(self, dot, DPEmoji(spaceID, focused), 8, focused ? 1 : 0.45);
}

static void DPTopDot_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTopDot_updateLayer, self);
    if (!DPProfileEmoji.on && !DPGet(self, &DPLabelKey)) return;
    NSString *spaceID = DPSpaceIDOf(self, DPSwiftValue(self.superview, @"dotViews"));
    BOOL focused = DPTopDotFocused(self, spaceID);
    DPUpdateEmojiLayer(self, focused, DPEmoji(spaceID, focused), NO);
}

static void DPRefresh(void) {
    for (const char *const *name = DPClasses(DPDiaSpaceSwitcher, DPDiaSpaceSwitcherItem, DPDiaPageIndicatorDot); *name; name++)
        for (NSView *view in DPFindAllViews(*name)) view.needsLayout = YES;
}

@interface DPEmojiField : NSTextField <NSTextFieldDelegate>
@property(copy) NSString *spaceID;
@end

@implementation DPEmojiField
- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    if (became) dispatch_async(dispatch_get_main_queue(), ^{ [NSApp orderFrontCharacterPalette:self]; });
    return became;
}

- (void)controlTextDidChange:(NSNotification *)note {
    __block NSString *last = @"";
    [self.stringValue enumerateSubstringsInRange:NSMakeRange(0, self.stringValue.length) options:NSStringEnumerationByComposedCharacterSequences
                                      usingBlock:^(NSString *character, NSRange _, NSRange __, BOOL *___) { last = character; }];
    last = [last stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![self.stringValue isEqual:last]) self.stringValue = last;
    NSMutableDictionary *emoji = [[DPSettingsDefaults() dictionaryForKey:DPEmojisKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    emoji[self.spaceID] = last.length ? last : nil;
    [DPSettingsDefaults() setObject:emoji forKey:DPEmojisKey];
    DPRefresh();
}
@end

static void DPAddEmojiRow(NSViewController *pane) {
    NSView *group = DPFindView(pane.view, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaSettingsFormGroup); });
    NSStackView *rows = (NSStackView *)DPSubview(group, "NSStackView");
    NSTextField *title = (NSTextField *)DPFindView(rows.arrangedSubviews.firstObject, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextField.class]; });
    NSString *spaceID = [DPSwiftValue(pane, @"spaceID") description];
    if (!rows || !title || !spaceID || DPGet(pane, &DPRowKey)) return;

    NSTextField *label = [NSTextField labelWithString:@"Emoji"];
    label.font = title.font;
    label.textColor = title.textColor;
    DPEmojiField *field = [DPEmojiField textFieldWithString:[DPSettingsDefaults() dictionaryForKey:DPEmojisKey][spaceID] ?: @""];
    field.spaceID = spaceID;
    field.delegate = field;
    field.alignment = NSTextAlignmentCenter;
    field.bezelStyle = NSTextFieldRoundedBezel;
    field.placeholderString = @"None";
    NSView *row = [NSView new];
    for (NSView *view in @[ label, field ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:view];
    }
    NSBox *line = [NSBox new];
    line.boxType = NSBoxSeparator;
    [rows addArrangedSubview:line];
    [rows addArrangedSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:42], [row.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [line.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [field.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.widthAnchor constraintEqualToConstant:64],
    ]];
    DPSet(pane, &DPRowKey, @[ line, row ]);
}

static void DPRemoveEmojiRow(NSViewController *pane) {
    for (NSView *view in DPGet(pane, &DPRowKey)) [view removeFromSuperview];
    DPSet(pane, &DPRowKey, nil);
}

static void DPApplyProfileEmoji(DPPatch *patch) {
    for (NSViewController *pane in DPProfilePanes.allObjects) {
        if (patch->on) DPAddEmojiRow(pane);
        else DPRemoveEmojiRow(pane);
    }
    DPRefresh();
}

static void DPApplyProfileEmojiCurrentOnly(DPPatch *patch) { DPRefresh(); }

static void DPProfilePane_viewDidLoad(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPProfilePane_viewDidLoad, self);
    [DPProfilePanes addObject:self];
    if (DPProfileEmoji.on) DPAddEmojiRow(self);
}

static void DPInstallProfileEmoji(void) {
    DPProfilePanes = [NSHashTable weakObjectsHashTable];
    DPHookClass(objc_getClass(DPDiaSpaceSwitcher), @selector(layout), (IMP)DPSidebarSwitcher_layout);
    DPHookClass(objc_getClass(DPDiaSpaceSwitcherItem), @selector(setFrame:), (IMP)DPSidebarItem_setFrame);
    DPHook(DPDiaSpaceSwitcherItem, @selector(layout), (IMP)DPSidebarItem_layout);
    DPHook(DPDiaSpaceSwitcherItem, @selector(updateLayer), (IMP)DPSidebarItem_updateLayer);
    DPHook(DPDiaPageIndicatorDot, @selector(layout), (IMP)DPTopDot_layout);
    DPHook(DPDiaPageIndicatorDot, @selector(updateLayer), (IMP)DPTopDot_updateLayer);
    DPHook(DPDiaProfilePane, @selector(viewDidLoad), (IMP)DPProfilePane_viewDidLoad);
}

DP_PATCH(DPProfileEmoji) {
    .key = @"profileEmoji",
    .order = 84,
    .defaultOn = YES,
    .title = @"Profile Emoji",
    .detail = @"Show an emoji in place of each profile’s dot in the profile switcher. Choose them in Settings › Profiles.",
    .symbol = @"emoji.face.grinning.inverse face.smiling.inverse",
    .tint = @"systemRedColor",
    .section = @"Profiles",
    .classes = DPClasses(DPDiaSpaceSwitcher, DPDiaSpaceSwitcherItem, DPDiaPageIndicatorDot, DPDiaProfilePane, DPDiaSettingsFormGroup),
    .install = DPInstallProfileEmoji,
    .apply = DPApplyProfileEmoji,
};

DP_PATCH(DPProfileEmojiCurrentOnly) {
    .key = @"profileEmojiCurrentOnly",
    .order = 84,
    .defaultOn = NO,
    .title = @"Only on Current Profile",
    .detail = @"Show the emoji only for the active profile, keeping the other profiles as dots.",
    .symbol = @"person.crop.circle",
    .tint = @"systemRedColor",
    .requires = @"profileEmoji",
    .apply = DPApplyProfileEmojiCurrentOnly,
};
