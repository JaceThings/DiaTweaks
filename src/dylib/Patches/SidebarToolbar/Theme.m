#import "SidebarToolbar.h"

// Dia colours the address background and the navigation icons from the page, not from the bar's appearance.
// Each one it colours gets a subclass that keeps Dia's colour and, while docked, uses the app's instead.
static char DPThemedKey;

static NSView *DPThemedView(id object) {
    if ([object isKindOfClass:NSView.class]) return object;
    for (CALayer *layer = object; layer; layer = layer.superlayer)
        if ([layer.delegate isKindOfClass:NSView.class]) return (NSView *)layer.delegate;
    return nil;
}

static void DPApplyThemed(id object, SEL setter) {
    NSView *view = DPThemedView(object);
    __block id color = DPGet(object, &DPThemedKey);
    if (DPIsDocked(DPToolbarOf(view))) {
        NSColor *app = setter == @selector(setBackgroundColor:) ? NSColor.controlBackgroundColor : [NSColor.labelColor colorWithAlphaComponent:0.8];
        if (setter == @selector(setContentTintColor:)) color = app;
        else [view.effectiveAppearance performAsCurrentDrawingAppearance:^{ color = (__bridge id)app.CGColor; }];
    }
    IMP original = class_getMethodImplementation(class_getSuperclass(object_getClass(object)), setter);
    ((void (*)(id, SEL, id))original)(object, setter, color);
}

static void DPThemed_setColor(id self, SEL _cmd, id color) {
    DPSet(self, &DPThemedKey, color);
    DPApplyThemed(self, _cmd);
}

static Class DPThemed_class(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

// Takes over the object's colour, then applies it for the current docking.
void DPTheme(id object, SEL setter) {
    if (!object) return;
    Class base = object_getClass(object);
    if (class_getMethodImplementation(base, setter) != (IMP)DPThemed_setColor) {
        NSString *name = [@"DPThemed_" stringByAppendingString:NSStringFromClass(base)];
        Class cls = NSClassFromString(name);
        if (!cls) {
            cls = objc_allocateClassPair(base, name.UTF8String, 0);
            class_addMethod(cls, setter, (IMP)DPThemed_setColor, method_getTypeEncoding(class_getInstanceMethod(base, setter)));
            class_addMethod(cls, @selector(class), (IMP)DPThemed_class, method_getTypeEncoding(class_getInstanceMethod(base, @selector(class))));
            objc_registerClassPair(cls);
        }
        id current = [object isKindOfClass:CAShapeLayer.class] ? (__bridge id)((CAShapeLayer *)object).strokeColor
                   : [object isKindOfClass:CALayer.class]      ? (__bridge id)((CALayer *)object).backgroundColor
                                                               : ((NSImageView *)object).contentTintColor;
        DPSet(object, &DPThemedKey, current);
        object_setClass(object, cls);
    }
    DPApplyThemed(object, setter);
}

void DPThemeIcons(NSView *view) {
    for (CALayer *layer in view.layer.sublayers)
        if ([layer isKindOfClass:CAShapeLayer.class]) DPTheme(layer, @selector(setStrokeColor:));
    if ([view isKindOfClass:NSImageView.class]) DPTheme(view, @selector(setContentTintColor:));
    for (NSView *sub in view.subviews) DPThemeIcons(sub);
}
