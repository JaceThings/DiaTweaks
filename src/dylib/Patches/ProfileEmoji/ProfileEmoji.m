#import "ProfileIcons.h"

// The gap is between what's drawn, so emoji and dots sit the same distance apart in any mix.
static const CGFloat DPSidebarEmojiSize = 13.5, DPSidebarEmojiWidth = 16, DPSidebarDotWidth = 6, DPSidebarGap = 10;
static const CGFloat DPSidebarSymbolSize = 16, DPSidebarSymbolWidth = 32;
static char DPLabelKey;

// Keys are Swift SpaceIDs, which describe themselves as the ID.
static NSString *DPSpaceIDOf(NSView *view, NSDictionary *views) {
    for (id key in views) if (views[key] == view) return [key description];
    return nil;
}

static void DPShowIcon(NSView *host, NSView *dot, NSString *spaceID, CGFloat size, CGFloat alpha) {
    NSImage *image = DPProfileEmoji.on ? DPProfileSymbolImage(DPProfileSymbolName(spaceID), size) : nil;
    NSString *emoji = DPProfileEmoji.on ? DPProfileEmojiValue(spaceID) : nil;
    NSView *icon = DPGet(host, &DPLabelKey);
    if (!image && !emoji) {
        if (!icon) return;
        dot.hidden = NO;
        [icon removeFromSuperview];
        DPSet(host, &DPLabelKey, nil);
        return;
    }
    dot.hidden = YES;
    if (icon && [icon isKindOfClass:NSImageView.class] != (image != nil)) {
        [icon removeFromSuperview];
        icon = nil;
    }
    if (!icon) {
        icon = image ? [NSImageView new] : [NSTextField labelWithString:@""];
        icon.identifier = @"diatweaks.profileIcon";
        [host addSubview:icon];
        DPSet(host, &DPLabelKey, icon);
    }
    if (image) {
        NSImageView *view = (NSImageView *)icon;
        view.image = image;
        view.contentTintColor = NSColor.labelColor;
        view.imageScaling = NSImageScaleProportionallyDown;
        view.frame = NSMakeRect(0, 0, size, size);
    } else {
        NSTextField *label = (NSTextField *)icon;
        label.stringValue = emoji;
        label.font = [NSFont systemFontOfSize:size];
        label.alignment = NSTextAlignmentCenter;
        [label sizeToFit];
    }
    icon.alphaValue = alpha;
    icon.frame = (NSRect){ { NSMidX(host.bounds) - NSWidth(icon.frame) / 2, NSMidY(host.bounds) - NSHeight(icon.frame) / 2 }, icon.frame.size };
    if (image) icon.frame = [host backingAlignedRect:icon.frame options:NSAlignAllEdgesNearest];
}

static void DPShowSidebarItem(NSView *item) {
    NSString *spaceID = DPSpaceIDOf(item, DPSwiftValue(item.superview, @"itemViews"));
    BOOL selected = [DPSwiftValue(item, @"isSelected") boolValue];
    NSView *dot = DPSwiftValue(item, @"$__lazy_storage_$_dotView");
    [dot setFrameOrigin:NSMakePoint(round(NSMidX(item.bounds) - NSWidth(dot.frame) / 2), NSMinY(dot.frame))];
    CGFloat size = DPProfilePreferredSymbolName(DPProfileSymbolName(spaceID)) ? DPSidebarSymbolSize : DPSidebarEmojiSize;
    DPShowIcon(item, dot, spaceID, size, selected ? 1 : 0.45);
}

static CGFloat DPSidebarItemWidth(NSView *item, NSDictionary *views) {
    NSString *spaceID = DPSpaceIDOf(item, views);
    if (DPProfileEmoji.on && DPProfilePreferredSymbolName(DPProfileSymbolName(spaceID))) return DPSidebarSymbolWidth;
    return (DPProfileHasIcon(spaceID) ? DPSidebarEmojiWidth : DPSidebarDotWidth) + DPSidebarGap;
}

// Dia packs items 12 points apart, which crowds emoji, so each item gets its own width and the row stays centered.
// Dia also places items outside layout, such as after switching profiles.
static void DPSidebarItem_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSView *switcher = self.superview;
    NSDictionary *views = DPSwiftValue(switcher, @"itemViews");
    BOOL anyIcon = NO;
    for (id key in views) anyIcon = anyIcon || DPProfileHasIcon([key description]);
    if (anyIcon && NSWidth(frame) > 0 && NSWidth(frame) < DPSidebarDotWidth + DPSidebarGap) {
        CGFloat middle = NSMidX(switcher.bounds);
        NSInteger index = lround((NSMinX(frame) - (middle - views.count * NSWidth(frame) / 2)) / NSWidth(frame));
        NSMutableArray<NSView *> *row = [[views.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", self]] mutableCopy];
        [row sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) { return [@(NSMidX(a.frame)) compare:@(NSMidX(b.frame))]; }];
        [row insertObject:self atIndex:MIN(MAX(index, 0), (NSInteger)row.count)];
        CGFloat total = 0, x = 0;
        for (NSView *item in row) total += DPSidebarItemWidth(item, views);
        for (NSView *item in row) {
            if (item == self) break;
            x += DPSidebarItemWidth(item, views);
        }
        frame = NSMakeRect(round(middle - total / 2 + x), NSMinY(frame), DPSidebarItemWidth(self, views), NSHeight(frame));
    }
    DPCallOriginal(DPSidebarItem_setFrame, self, frame);
}

static void DPSidebarItem_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_layout, self);
    DPShowSidebarItem(self);
}

static void DPSidebarItem_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_updateLayer, self);
    DPShowSidebarItem(self);
}

static void DPShowTopItem(NSView *self) {
    NSView *indicator = self.superview;
    NSString *spaceID = DPSpaceIDOf(self, DPSwiftValue(indicator, @"dotViews"));
    BOOL focused = [[DPSwiftValue(indicator, @"focusedSpaceID") description] isEqual:spaceID];
    CGFloat size = DPProfilePreferredSymbolName(DPProfileSymbolName(spaceID)) ? 10 : 8;
    DPShowIcon(self, self.subviews.firstObject, spaceID, size, focused ? 1 : 0.45);
}

static void DPTopDot_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTopDot_layout, self);
    DPShowTopItem(self);
}

static void DPTopDot_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTopDot_updateLayer, self);
    DPShowTopItem(self);
}

void DPRefreshProfileIcons(void) {
    for (NSString *name in @[ @DPDiaSpaceSwitcher, @DPDiaSpaceSwitcherItem, @DPDiaPageIndicatorDot ])
        for (NSView *view in DPFindViews(name.UTF8String)) view.needsLayout = YES;
    DPUpdateProfilePanes();
}

static void DPRefresh(DPPatch *patch) {
    DPRefreshProfileIcons();
}

static void DPProfilePane_viewDidLoad(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPProfilePane_viewDidLoad, self);
    DPTrackProfilePane(self);
}

static NSString *DPVerifyProfileIcons(DPPatch *patch) {
    for (NSString *className in @[ @DPDiaSpaceSwitcherItem, @DPDiaPageIndicatorDot ]) {
        BOOL sidebar = [className isEqual:@DPDiaSpaceSwitcherItem];
        for (NSView *host in DPFindViews(className.UTF8String)) {
            if (host.hiddenOrHasHiddenAncestor) continue;
            NSDictionary *views = DPSwiftValue(host.superview, sidebar ? @"itemViews" : @"dotViews");
            NSString *spaceID = DPSpaceIDOf(host, views);
            NSView *icon = DPGet(host, &DPLabelKey);
            BOOL expected = DPProfileHasIcon(spaceID);
            if (expected != (icon != nil)) return @"Profile icon visibility does not match the selection";
            NSView *dot = sidebar ? DPSwiftValue(host, @"$__lazy_storage_$_dotView") : host.subviews.firstObject;
            if (!dot || dot.hidden != expected) return @"Profile dot visibility does not match the selection";
            if (!expected) continue;
            BOOL selected = sidebar ? [DPSwiftValue(host, @"isSelected") boolValue]
                : [[DPSwiftValue(host.superview, @"focusedSpaceID") description] isEqual:spaceID];
            if (fabs(icon.alphaValue - (selected ? 1 : 0.45)) > 0.01) return @"Profile icon opacity is stale";
            BOOL symbol = DPProfileSymbolImage(DPProfileSymbolName(spaceID), 13.5) != nil;
            if (symbol != [icon isKindOfClass:NSImageView.class]) return @"Profile icon type does not match the selection";
            CGFloat tolerance = 0.5 / host.window.backingScaleFactor + 0.01;
            if (fabs(NSMidX(icon.frame) - NSMidX(host.bounds)) > tolerance || fabs(NSMidY(icon.frame) - NSMidY(host.bounds)) > tolerance) return @"Profile icon is not centered";
            if (symbol) {
                NSImageView *image = (NSImageView *)icon;
                if (!image.image.isTemplate || ![image.contentTintColor isEqual:NSColor.labelColor]) return @"Profile symbol is not theme-adaptive monochrome";
                CGFloat size = sidebar ? 16 : 10;
                if (fabs(NSWidth(image.frame) - size) > 0.01 || fabs(NSHeight(image.frame) - size) > 0.01 || !NSContainsRect(host.bounds, image.frame)) return @"Profile symbol size or clipping is incorrect";
                NSRect pixels = [host convertRectToBacking:image.frame];
                if (fabs(NSMinX(pixels) - round(NSMinX(pixels))) > 0.01 || fabs(NSMinY(pixels) - round(NSMinY(pixels))) > 0.01) return @"Profile symbol is not pixel-aligned";
            } else {
                NSTextField *label = (NSTextField *)icon;
                if (![label.stringValue isEqual:DPProfileEmojiValue(spaceID)] || label.font.pointSize != (sidebar ? 13.5 : 8)) return @"Profile emoji content or size is incorrect";
            }
        }
    }
    return nil;
}

static void DPInstallProfileEmoji(void) {
    DPEmojiDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    DPHookClass(objc_getClass(DPDiaSpaceSwitcherItem), @selector(setFrame:), (IMP)DPSidebarItem_setFrame);
    DPHook(DPDiaSpaceSwitcherItem, @selector(layout), (IMP)DPSidebarItem_layout);
    DPHook(DPDiaSpaceSwitcherItem, @selector(updateLayer), (IMP)DPSidebarItem_updateLayer);
    DPHook(DPDiaPageIndicatorDot, @selector(layout), (IMP)DPTopDot_layout);
    DPHook(DPDiaPageIndicatorDot, @selector(updateLayer), (IMP)DPTopDot_updateLayer);
    DPHook(DPDiaProfilePane, @selector(viewDidLoad), (IMP)DPProfilePane_viewDidLoad);
}

DP_PATCH(DPProfileEmoji) {
    .key = @"profileEmoji",
    .order = 78,
    .defaultOn = YES,
    .title = @"Profile Emoji",
    .detail = @"Show an emoji or monochrome icon in place of each profile’s dot. Choose them in Settings › Profiles.",
    .symbol = @"emoji.face.grinning.inverse face.smiling.inverse",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSpaceSwitcher, DPDiaSpaceSwitcherItem, DPDiaPageIndicatorDot, DPDiaProfilePane, DPDiaSettingsFormGroup),
    .install = DPInstallProfileEmoji,
    .apply = DPRefresh,
    .verify = DPVerifyProfileIcons,
};
