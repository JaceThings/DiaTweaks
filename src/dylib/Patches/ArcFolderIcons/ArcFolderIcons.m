#import "ArcFolderIcons.h"

@interface NSObject (DPFolderSwiftFields)
- (id)safeSwiftValueForKey:(NSString *)key;  // AXCoreUtilities: reads Swift properties the Obj-C runtime hides.
@end

extern DPPatch DPArcFolderIcons;
static char DPImageKey;  // On an icon view: @[Dia's image, ours]
static char DPTintKey;   // On a window: the sidebar colour its folders were last drawn in.

// Tab groups in the sidebar, then in the tab strip. Both keep their icon views and state under the same names.
static NSArray<NSView *> *DPGroupViews(void) {
    return [DPFindViews(DPDiaTabGroupCell) arrayByAddingObjectsFromArray:DPFindViews(DPDiaTabGroupView)];
}

// Dia's own folder: its fallback icon, or the 📁 it gives imported Arc folders. Other emoji people picked stay.
static NSString *DPFolderState(NSView *cell) {
    NSString *state = [[[[cell safeSwiftValueForKey:@"viewModel"] safeSwiftValueForKey:@"stateSubject"] safeSwiftValueForKey:@"currentValue"] description];
    return [state containsString:@"Icon.custom("] && ![state containsString:@"emoji(\"📁\")"] ? nil : state;
}

static void DPStyleIcon(NSView *cell) {
    NSString *state = DPArcFolderIcons.on ? DPFolderState(cell) : nil;
    BOOL dark = NO;
    NSColor *tint = state ? DPSidebarTint(cell.window, &dark) : nil;
    DPFolderLook look = [state containsString:@".expanded("] ? DPFolderOpen : [state containsString:@".peeked("] ? DPFolderPeeked : DPFolderClosed;
    NSImage *ours = state ? DPFolderImage(look, tint, dark) : nil;
    for (NSString *name in @[ @"customIconView", @"fallbackIconView" ]) {
        NSImageView *icon = [cell safeSwiftValueForKey:[@"$__lazy_storage_$_" stringByAppendingString:name]];
        if (![icon isKindOfClass:NSImageView.class]) continue;
        NSImage *dia = DPDiaValue(icon, &DPImageKey, icon.image);
        if (!dia) continue;  // The unused one of the two has no image.
        NSImage *image = state && !icon.hidden ? ours : dia;
        if (icon.image != image) icon.image = image;  // Only on a change: setting it lays the cell out again.
        if (image == dia) DPSet(icon, &DPImageKey, nil);
        else DPOverride(icon, &DPImageKey, dia, image);
    }
}

static void DPGroup_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGroup_layout, self);
    DPStyleIcon(self);
}

static void DPGroup_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPGroup_updateLayer, self);
    DPStyleIcon(self);
}

// Switching spaces recolours the window's gradient without laying out the sidebar's rows, so they're redrawn from here.
static void DPGradient_setColors(CAGradientLayer *self, SEL _cmd, NSArray *colors) {
    DPCallOriginal(DPGradient_setColors, self, colors);
    NSView *gradient = (NSView *)self.superlayer.delegate;  // Dia's gradient view, whose backing layer holds this one.
    if (!DPArcFolderIcons.on || ![gradient isKindOfClass:NSView.class] || !DPIsKind(gradient.superview, DPDiaWindowTint)) return;
    __weak NSWindow *window = gradient.window;
    dispatch_async(dispatch_get_main_queue(), ^{  // Once Dia has handed the layer its new colours.
        BOOL dark = NO;
        NSColor *tint = window ? DPSidebarTint(window, &dark) : nil;
        NSString *drawn = [NSString stringWithFormat:@"%@ %d", tint, dark];
        if (!tint || [DPGet(window, &DPTintKey) isEqual:drawn]) return;
        DPSet(window, &DPTintKey, drawn);
        for (NSView *cell in DPGroupViews()) if (cell.window == window) DPStyleIcon(cell);
    });
}

static void DPApplyArcFolderIcons(DPPatch *patch) {
    for (NSView *cell in DPGroupViews()) DPStyleIcon(cell);
}

static NSString *DPVerifyArcFolderIcons(DPPatch *patch) {
    for (NSView *cell in DPGroupViews()) {
        if (!DPFolderState(cell)) continue;
        NSView *container = [cell safeSwiftValueForKey:@"$__lazy_storage_$_iconContainerView"];
        NSImageView *icon = (NSImageView *)DPFindView(container, ^BOOL(NSView *view) { return [view isKindOfClass:NSImageView.class] && !view.hidden; });
        if (DPIsFolderImage(icon.image) != patch->on) return patch->on ? @"a folder still has Dia's icon" : @"a folder still has the Arc icon";
    }
    return nil;
}

static void DPInstallArcFolderIcons(void) {
    DPHook(DPDiaTabGroupCell, @selector(layout), (IMP)DPGroup_layout);
    DPHook(DPDiaTabGroupCell, @selector(updateLayer), (IMP)DPGroup_updateLayer);
    DPHook(DPDiaTabGroupView, @selector(layout), (IMP)DPGroup_layout);
    DPHook(DPDiaTabGroupView, @selector(updateLayer), (IMP)DPGroup_updateLayer);
    DPHook("CAGradientLayer", @selector(setColors:), (IMP)DPGradient_setColors);
}

DP_PATCH(DPArcFolderIcons) {
    .key = @"arcFolderIcons",
    .order = 77,
    .title = @"Arc Folder Icons",
    .detail = @"Show tab groups with Arc’s outlined folder in the sidebar’s colour, open while the group is expanded and with three dots while it’s collapsed around the open tab. Icons you picked for a group stay.",
    .symbol = @"folder.fill",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaTabGroupCell),
    .install = DPInstallArcFolderIcons,
    .apply = DPApplyArcFolderIcons,
    .verify = DPVerifyArcFolderIcons,
};
