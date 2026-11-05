#import "DeveloperMode.h"

// Arc's hazard tape around a tab: yellow with black dashes over a faint yellow tint, drawn just inside the row.
static const CGFloat DPBorderWidth = 2, DPDashLength = 8, DPRadiusRatio = 0.35, DPTintAlpha = 0.06;
static char DPBorderKey;
static NSSet<NSString *> *DPShownTabs;

@interface DPDevTabBorder : NSView
@property (nonatomic) CGFloat radius;
@end

@implementation DPDevTabBorder

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)drawRect:(NSRect)dirty {
    NSRect rect = NSInsetRect(self.bounds, DPBorderWidth / 2, DPBorderWidth / 2);
    CGFloat radius = MAX(self.radius - DPBorderWidth / 2, 0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
    path.lineWidth = DPBorderWidth;
    NSColor *yellow = [NSColor colorWithSRGBRed:1 green:0.8 blue:0.04 alpha:1];
    [[yellow colorWithAlphaComponent:DPTintAlpha] setFill];
    [path fill];
    [yellow setStroke];
    [path stroke];
    CGFloat dashes[] = {DPDashLength, DPDashLength};
    [path setLineDash:dashes count:2 phase:0];
    [NSColor.blackColor setStroke];
    [path stroke];
}

@end

// A row's tab ID sits in its TabView's view model as a Swift String. A 36-character UUID is too long to live inline, so
// the string is a count word and a pointer to storage whose text starts 32 bytes in. Anything else reads as no ID.
static NSString *DPRowTabID(NSView *row) {
    NSView *tab = row.superview.superview;
    if (!DPIsKind(tab, DPDiaTab)) return nil;
    void **model = DPIvar(tab, "viewModel");
    uint64_t *string = model && *model ? DPIvar((__bridge id)*model, "tabID") : NULL;
    if (!string || string[0] >> 60 != 0xF || (string[0] & 0xFFFFFFFFFFFF) != 36 || string[1] >> 60 != 0) return nil;
    return [[NSString alloc] initWithBytes:(const void *)(uintptr_t)(string[1] + 32) length:36 encoding:NSUTF8StringEncoding];
}

// The capsule Dia draws for a tab: its frame in the row, and the corner radius of the background behind it.
static BOOL DPCapsule(NSView *row, NSRect *frame, CGFloat *radius) {
    void **slot = DPIvar(row.superview.superview, "$__lazy_storage_$_backgroundView");
    NSView *background = slot ? (__bridge NSView *)*slot : nil;
    NSRect *capsule = DPIvar(row, "capsuleBackgroundFrame");
    CGFloat *corner = DPIsKind(background, DPDiaTabBackground) ? DPIvar(background, "highlightCornerRadius") : NULL;
    if (!capsule || !corner || NSIsEmptyRect(*capsule) || *corner <= 0) return NO;
    *frame = *capsule;
    *radius = *corner;
    return YES;
}

void DPPlaceTabBorder(NSView *row) {
    NSString *tabID = DPShownTabs.count ? DPRowTabID(row) : nil;
    DPDevTabBorder *border = DPGet(row, &DPBorderKey);
    if (!tabID || ![DPShownTabs containsObject:tabID]) {
        [border removeFromSuperview];
        DPSet(row, &DPBorderKey, nil);
        return;
    }
    if (!border) {
        border = [DPDevTabBorder new];
        DPSet(row, &DPBorderKey, border);
        [row addSubview:border];
    }
    NSRect frame = row.bounds;
    CGFloat radius = NSHeight(frame) * DPRadiusRatio;
    DPCapsule(row, &frame, &radius);
    border.frame = frame;
    border.radius = radius;
    border.needsDisplay = YES;
}

void DPRefreshTabBorders(void) {
    DPShownTabs = DPDeveloperMode.on ? DPDevTabIDs() : nil;
    for (NSView *row in DPFindViews(DPDiaTabRow)) DPPlaceTabBorder(row);
}

NSString *DPVerifyTabBorders(DPPatch *patch) {
    for (NSView *row in DPFindViews(DPDiaTabRow)) {
        if (row.hiddenOrHasHiddenAncestor) continue;
        NSString *tabID = DPRowTabID(row);
        if (!tabID) return @"a sidebar tab's ID can't be read";
        BOOL shown = patch->on && [DPShownTabs containsObject:tabID];
        if ((DPGet(row, &DPBorderKey) != nil) != shown) return shown ? @"developer tab border missing" : @"developer tab border stays";
    }
    return nil;
}
