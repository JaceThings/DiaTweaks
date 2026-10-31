#import "SidebarToolbar.h"

// Docked, the address buttons that appear on hover sit over the text, which fades out beneath them.
static char DPOverlayKey, DPSelectableKey;

static NSStackView *DPAddressStack(NSView *address) {
    return (NSStackView *)DPFindView(address, ^BOOL(NSView *v) {
        return [v isKindOfClass:NSStackView.class] && DPIsKind(((NSStackView *)v).arrangedSubviews.firstObject, DPDiaAddressTitle);
    });
}

static void DPLayoutOverlay(NSStackView *stack) {
    NSArray<NSView *> *controls = DPGet(stack, &DPOverlayKey);
    CGFloat x = NSMaxX(stack.frame), height = NSHeight(stack.superview.bounds);
    for (NSView *control in controls.reverseObjectEnumerator) {
        if (control.hidden) continue;
        // Dia's size for them depends on when they were taken out of the stack; this one doesn't.
        NSSize size = NSMakeSize(height - 8, height - 8);
        x -= size.width;
        control.frame = NSMakeRect(x, round((height - size.height) / 2), size.width, size.height);
        x -= stack.spacing;
    }
    CGFloat width = NSWidth(stack.bounds), edge = x - NSMinX(stack.frame);
    if (edge >= width) {
        stack.layer.mask = nil;
        return;
    }
    CAGradientLayer *mask = [stack.layer.mask isKindOfClass:CAGradientLayer.class] ? (CAGradientLayer *)stack.layer.mask : [CAGradientLayer layer];
    mask.frame = stack.layer.bounds;
    mask.startPoint = CGPointMake(0, 0.5);
    mask.endPoint = CGPointMake(1, 0.5);
    mask.colors = @[(id)NSColor.blackColor.CGColor, (id)NSColor.blackColor.CGColor, (id)NSColor.clearColor.CGColor];
    mask.locations = @[@0, @(MAX(edge - 20, 0) / width), @(MAX(edge, 0) / width)];
    stack.layer.mask = mask;
}

static void DPOverlay_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPOverlay_setHidden, self, hidden);
    NSStackView *stack = DPGet(self, &DPOverlayKey);
    if (stack) DPLayoutOverlay(stack);
}

// Dia removes views from the stacks we took them out of, which NSStackView asserts against; finish its removal for it.
// Every removal from a stack passes through this private method, whichever public one Dia calls.
static void DPStack_removeView(NSStackView *self, SEL _cmd, NSView *view, BOOL animated, BOOL fromHierarchy) {
    BOOL ours = DPGet(view, &DPOverlayKey) == self || DPDownloadsHome(view) == self;
    if (!ours || [self.views containsObject:view] || [self.detachedViews containsObject:view])
        return DPCallOriginal(DPStack_removeView, self, view, animated, fromHierarchy);
    DPForgetDownloadsHome(view);
    DPSet(view, &DPOverlayKey, nil);
    [DPGet(self, &DPOverlayKey) removeObject:view];
    if (fromHierarchy) [view removeFromSuperview];
}

static void DPArrangeOverlay(NSView *address, BOOL docked) {
    NSStackView *stack = DPAddressStack(address);
    if (!stack) return;
    NSMutableArray<NSView *> *controls = DPGet(stack, &DPOverlayKey);
    if (docked) {
        controls = controls ?: [NSMutableArray new];
        for (NSView *control in stack.arrangedSubviews.copy) {
            if (control == stack.arrangedSubviews.firstObject) continue;
            DPSet(control, &DPOverlayKey, stack);
            DPHookClass(control.class, @selector(setHidden:), (IMP)DPOverlay_setHidden);
            [stack removeView:control];
            control.translatesAutoresizingMaskIntoConstraints = YES;
            [stack.superview addSubview:control];
            if (![controls containsObject:control]) [controls addObject:control];
        }
        DPSet(stack, &DPOverlayKey, controls);
        [address layoutSubtreeIfNeeded];
        DPLayoutOverlay(stack);
    } else if (controls) {
        DPSet(stack, &DPOverlayKey, nil);
        for (NSView *control in controls) {
            DPSet(control, &DPOverlayKey, nil);
            [control removeFromSuperview];
            control.translatesAutoresizingMaskIntoConstraints = NO;
            [stack addView:control inGravity:NSStackViewGravityLeading];
        }
        stack.layer.mask = nil;
    }
}

void DPArrangeAddress(NSView *address, BOOL docked) {
    CALayer *pill = address.subviews.firstObject.layer;
    if (docked || object_getClass(pill) != pill.class) DPTheme(pill, @selector(setBackgroundColor:));
    // Docked, the address text can't be selected or show a text cursor until the address is opened.
    NSTextView *text = (NSTextView *)DPFindView(address, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressText); });
    NSNumber *selectable = DPGet(text, &DPSelectableKey);
    if (docked && text.selectable) {
        if (!selectable) DPSet(text, &DPSelectableKey, @YES);
        text.selectable = NO;
    } else if (!docked && selectable) {
        text.selectable = selectable.boolValue;
        DPSet(text, &DPSelectableKey, nil);
    }
    DPArrangeOverlay(address, docked);
}

void DPInstallAddress(void) {
    DPHook("NSStackView", NSSelectorFromString(@"_removeView:animated:removeFromViewHierarchy:"), (IMP)DPStack_removeView);
}
