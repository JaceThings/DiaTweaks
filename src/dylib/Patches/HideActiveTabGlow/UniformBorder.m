#import "HideActiveTabGlow.h"

static char DPColorsKey;
static NSHashTable<CAGradientLayer *> *DPBorders;

static CAGradientLayer *DPBorderIn(NSView *shape) {
    void **slot = DPIvar(shape, "$__lazy_storage_$_gradientBorderLayer");
    id layer = slot ? (__bridge id)*slot : nil;
    return [layer isKindOfClass:CAGradientLayer.class] ? layer : nil;
}

// Use Dia's middle opacity: the outline stays subtle and follows its light/dark palette.
static NSArray *DPUniformColors(NSArray *colors) {
    if (!colors.count) return colors;
    NSArray *sorted = [colors sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        CGFloat x = CGColorGetAlpha((__bridge CGColorRef)a), y = CGColorGetAlpha((__bridge CGColorRef)b);
        return x < y ? NSOrderedAscending : x > y ? NSOrderedDescending : NSOrderedSame;
    }];
    NSMutableArray *flat = [NSMutableArray new];
    for (NSUInteger i = 0; i < colors.count; i++) [flat addObject:sorted[colors.count / 2]];
    return flat;
}

static void DPBorder_setColors(CAGradientLayer *self, SEL _cmd, NSArray *colors) {
    if (DPGet(self, &DPColorsKey)) {
        DPSet(self, &DPColorsKey, colors ?: NSNull.null);
        if (DPHideActiveTabGlow.on) colors = DPUniformColors(colors);
    }
    DPCallOriginal(DPBorder_setColors, self, colors);
}

void DPStyleUniformTabBorder(NSView *shape) {
    CAGradientLayer *border = DPBorderIn(shape);
    if (!border || !DPHideActiveTabGlow.on) return;
    id saved = DPGet(border, &DPColorsKey);
    if (!saved) {
        if (!DPBorders) DPBorders = [NSHashTable weakObjectsHashTable];
        DPSet(border, &DPColorsKey, saved = border.colors ?: NSNull.null);
        [DPBorders addObject:border];
        DPHookClass(border.class, @selector(setColors:), (IMP)DPBorder_setColors);
    }
    border.colors = saved == NSNull.null ? nil : saved;
}

void DPRestoreTabBorders(void) {
    for (CAGradientLayer *border in DPBorders.allObjects) {
        id saved = DPGet(border, &DPColorsKey);
        border.colors = saved == NSNull.null ? nil : saved;
        DPSet(border, &DPColorsKey, nil);
    }
    [DPBorders removeAllObjects];
}

NSString *DPVerifyUniformTabBorder(NSView *shape, BOOL on) {
    CAGradientLayer *border = DPBorderIn(shape);
    id saved = DPGet(border, &DPColorsKey);
    if (on && border && !saved) return @"a tab's border isn't watched";
    if (on && border.colors.count && ![border.colors isEqual:DPUniformColors(border.colors)]) return @"a tab's border still fades";
    return !on && saved ? @"a tab border wasn't restored" : nil;
}
