#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, DPTweak) {
    DPEdgeToEdge, DPHideToolbar, DPSquareSidebarCorners, DPAnimatedCount,
    DPHideChatButton = DPAnimatedCount, DPHideSidebarButton, DPHideChatsButton, DPHideRecentTabsButton, DPOverlayScrollbars, DPLittleDia, DPTweakCount
};

static NSString *const DPKeys[DPTweakCount] = {@"edgeToEdge", @"hideToolbar", @"squareSidebarCorners", @"hideChatButton", @"hideSidebarButton", @"hideChatsButton", @"hideRecentTabsButton", @"overlayScrollbars", @"littleDia"};
static const BOOL DPDefaultsOn[DPTweakCount] = {YES, NO, YES, NO, NO, NO, NO, NO, NO};
static const CGFloat DPWindowPadding = 6;
static const CFTimeInterval DPAnimationDuration = 0.25;

static BOOL DPOn[DPTweakCount];
static CGFloat DPProgress[DPAnimatedCount];
static NSUserDefaults *DPDefaults;
static NSHashTable<NSView *> *DPContainers, *DPPanes, *DPBars, *DPSuppressed;
static NSHashTable<NSWindow *> *DPLittleWindows;
static char DPRequestedFrameKey, DPAssignedFrameKey, DPButtonKey, DPBaseRadiusKey, DPAssignedRadiusKey, DPFillsKey, DPChatKey, DPOriginalPathKey, DPAssignedPathKey, DPCollapsedKey, DPSearchItemKey, DPBackdropKey, DPLittleIDKey;

static NSString *DPCLI(void) {
    return [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"DiaPatches/bin/diapatch"];
}

static void DPRunCLI(NSArray<NSString *> *args, void (^completion)(NSString *output)) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSTask *task = [NSTask new];
        task.executableURL = [NSURL fileURLWithPath:DPCLI()];
        task.arguments = args;
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = NSFileHandle.fileHandleWithNullDevice;
        NSString *output = nil;
        if ([task launchAndReturnError:nil]) {
            NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
            [task waitUntilExit];
            if (task.terminationStatus == 0) output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(output); });
    });
}

static void DPHandOffAndQuit(NSString *command) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:DPCLI()];
    task.arguments = @[command, @"--wait", @(getpid()).stringValue, @"--relaunch"];
    if ([task launchAndReturnError:nil]) [NSApp terminate:nil];
}

static NSView *DPFindView(NSView *root, BOOL (^match)(NSView *)) {
    if (!root || match(root)) return root;
    for (NSView *sub in root.subviews) {
        NSView *found = DPFindView(sub, match);
        if (found) return found;
    }
    return nil;
}

#pragma mark - Hooks

typedef struct { Class cls; SEL sel; IMP imp; } DPOriginal;
static DPOriginal DPOriginals[32];
static int DPOriginalCount;

static void DPHook(Class cls, SEL sel, IMP replacement) {
    Method method = cls ? class_getInstanceMethod(cls, sel) : NULL;
    if (!method || method_getImplementation(method) == replacement || DPOriginalCount == 32) return;
    IMP original = method_getImplementation(method);
    if (!class_addMethod(cls, sel, replacement, method_getTypeEncoding(method))) method_setImplementation(method, replacement);
    DPOriginals[DPOriginalCount++] = (DPOriginal){cls, sel, original};
}

static IMP DPOriginalIMP(id object, SEL sel) {
    for (Class c = object_getClass(object); c; c = class_getSuperclass(c))
        for (int i = 0; i < DPOriginalCount; i++)
            if (DPOriginals[i].cls == c && DPOriginals[i].sel == sel) return DPOriginals[i].imp;
    abort();
}

#define DPCallOriginal(type, object, sel, ...) ((type)DPOriginalIMP(object, sel))(object, sel, ##__VA_ARGS__)

#pragma mark - Toolbar buttons

static BOOL DPIsKind(NSView *view, NSString *className) {
    Class cls = NSClassFromString(className);
    return cls && [view isKindOfClass:cls];
}

static NSInteger DPButtonTweak(NSView *view) {
    NSNumber *tweak = objc_getAssociatedObject(view, &DPButtonKey);
    if (tweak) return tweak.integerValue;
    NSString *label = view.accessibilityLabel;
    NSInteger match = [label isEqualToString:@"Chat with this tab"]                ? DPHideChatButton
                    : [label isEqualToString:@"Toggle sidebar"]                    ? DPHideSidebarButton
                    : [label isEqualToString:@"Recent tabs"]                       ? DPHideRecentTabsButton
                    : DPIsKind(view, @"_TtC10DiaLibrary17LibraryButtonView")       ? DPHideChatsButton
                    : DPIsKind(view, @"_TtC10TabSidebar15LibraryCellView")         ? DPHideChatsButton
                                                                                   : -1;
    if (match >= 0) objc_setAssociatedObject(view, &DPButtonKey, @(match), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return match;
}

static void DPButton_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    NSInteger tweak = DPButtonTweak(self);
    BOOL suppress = !hidden && tweak >= 0 && DPOn[tweak];
    if (suppress) [DPSuppressed addObject:self];
    else [DPSuppressed removeObject:self];
    DPCallOriginal(void (*)(id, SEL, BOOL), self, _cmd, hidden || suppress);
}

static void DPEnforceButton(NSView *view) {
    NSInteger tweak = DPButtonTweak(view);
    if (tweak < 0) return;
    DPHook(view.class, @selector(setHidden:), (IMP)DPButton_setHidden);
    if (!DPOn[tweak] || view.hidden) return;
    [DPSuppressed addObject:view];
    DPCallOriginal(void (*)(id, SEL, BOOL), view, @selector(setHidden:), YES);
}

static void DPButton_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    DPEnforceButton(self);
}

static BOOL DPEnforceButtons(NSView *view) {
    if (DPButtonTweak(view) >= 0) {
        DPHook(view.class, @selector(viewDidMoveToWindow), (IMP)DPButton_viewDidMoveToWindow);
        BOOL wasHidden = view.hidden;
        DPEnforceButton(view);
        return view.hidden != wasHidden;
    }
    BOOL changed = NO;
    for (NSView *sub in view.subviews) changed |= DPEnforceButtons(sub);
    return changed;
}

static void DPBar_layout(NSView *self, SEL _cmd) {
    [DPBars addObject:self];
    DPEnforceButtons(self);
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
}

static void DPRelayoutBars(void) {
    for (NSView *bar in DPBars.allObjects) {
        bar.needsLayout = YES;
        [bar layoutSubtreeIfNeeded];
    }
}

// With everything in the sidebar footer hidden, the view above it grows over the footer's space.
static void DPSidebar_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    NSView *sidebar = self.view, *footer = nil;
    [DPBars addObject:sidebar];
    for (NSView *sub in sidebar.subviews) if (DPIsKind(sub, @"_TtC10TabSidebar26SidebarContainerFooterView")) footer = sub;
    if (!footer || !sidebar.isFlipped) return;
    DPEnforceButtons(footer);
    BOOL empty = DPOn[DPHideChatsButton] && DPOn[DPHideRecentTabsButton];
    for (NSView *item in footer.subviews) empty &= item.hidden;
    NSHashTable<NSView *> *grown = objc_getAssociatedObject(footer, &DPCollapsedKey);
    if (empty) {
        if (!grown) objc_setAssociatedObject(footer, &DPCollapsedKey, grown = [NSHashTable weakObjectsHashTable], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        footer.hidden = YES;
        for (NSView *sub in sidebar.subviews) {
            if (sub == footer || fabs(NSMaxY(sub.frame) - NSMinY(footer.frame)) > 0.5) continue;
            [sub setFrameSize:NSMakeSize(NSWidth(sub.frame), NSMaxY(footer.frame) - NSMinY(sub.frame))];
            [grown addObject:sub];
        }
    } else if (grown) {
        objc_setAssociatedObject(footer, &DPCollapsedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        footer.hidden = NO;
        for (NSView *sub in grown)
            if (fabs(NSMaxY(sub.frame) - NSMaxY(footer.frame)) < 0.5)
                [sub setFrameSize:NSMakeSize(NSWidth(sub.frame), NSMinY(footer.frame) - NSMinY(sub.frame))];
    }
}

// The tab strip's Chats and recent tabs buttons sit directly in its root view, beside the tabs.
static void DPTabStrip_viewWillLayout(NSViewController *self, SEL _cmd) {
    [DPBars addObject:self.view];
    for (NSView *sub in self.view.subviews) if (DPButtonTweak(sub) >= 0) DPEnforceButtons(sub);
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
}

static void DPRestoreButtons(DPTweak tweak) {
    for (NSView *view in DPSuppressed.allObjects)
        if (DPButtonTweak(view) == tweak) view.hidden = NO;
}

#pragma mark - Edge-to-edge

// With Chat open Dia animates sidebar changes from its own geometry, so edge-to-edge steps aside.
static NSView *DPChatCard(NSView *container) {
    NSView *content = DPFindView(container, ^BOOL(NSView *v) { return v != container && v.layer.masksToBounds && v.layer.cornerRadius > 0; });
    NSSize size = content.bounds.size;
    BOOL (^isCard)(NSView *) = ^BOOL(NSView *v) {
        return v.layer.masksToBounds && v.layer.cornerRadius > 0 && NSWidth(v.bounds) > size.width / 4 && NSHeight(v.bounds) > size.height / 2;
    };
    for (NSView *root in content.subviews)
        for (NSView *host in root.subviews) {
            if (NSMinX(host.frame) < 2 && NSMinY(host.frame) < 2) continue;
            if (isCard(host)) return host;
            for (NSView *card in host.subviews) if (isCard(card)) return card;
        }
    return nil;
}

static NSRect DPEdgeToEdgeFrame(NSView *view, NSRect frame) {
    CGFloat inset = DPProgress[DPEdgeToEdge] * DPWindowPadding;
    NSView *superview = view.superview;
    if (inset == 0 || !superview || DPChatCard(view)) return frame;
    NSRect bounds = superview.bounds;
    CGFloat left = NSMinX(frame) - NSMinX(bounds), right = NSMaxX(bounds) - NSMaxX(frame);
    CGFloat top = superview.isFlipped ? NSMinY(frame) - NSMinY(bounds) : NSMaxY(bounds) - NSMaxY(frame);
    CGFloat bottom = superview.isFlipped ? NSMaxY(bounds) - NSMaxY(frame) : NSMinY(frame) - NSMinY(bounds);
    BOOL (^isPadding)(CGFloat) = ^BOOL(CGFloat gap) { return fabs(gap - DPWindowPadding) < 0.5; };
    if (isPadding(left)) frame.origin.x -= inset, frame.size.width += inset;
    if (isPadding(right)) frame.size.width += inset;
    if (isPadding(top)) {
        frame.size.height += inset;
        if (superview.isFlipped) frame.origin.y -= inset;
    }
    if (isPadding(bottom)) {
        frame.size.height += inset;
        if (!superview.isFlipped) frame.origin.y -= inset;
    }
    return frame;
}

static void DPSetCornerRadius(NSView *container, CGFloat inset) {
    static ptrdiff_t offset = -1;
    if (offset < 0) {
        Ivar ivar = class_getInstanceVariable(container.class, "cornerRadius");
        offset = ivar ? ivar_getOffset(ivar) : 0;
    }
    if (!offset) return;
    CGFloat *radius = (CGFloat *)((uint8_t *)(__bridge void *)container + offset);
    NSNumber *assigned = objc_getAssociatedObject(container, &DPAssignedRadiusKey);
    CGFloat base = assigned && assigned.doubleValue == *radius ? [objc_getAssociatedObject(container, &DPBaseRadiusKey) doubleValue] : *radius;
    objc_setAssociatedObject(container, &DPBaseRadiusKey, @(base), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(container, &DPAssignedRadiusKey, @(base + inset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (*radius == base + inset) return;
    *radius = base + inset;
    container.needsLayout = YES;
}

static void DPContainer_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    objc_setAssociatedObject(self, &DPRequestedFrameKey, [NSValue valueWithRect:frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [DPContainers addObject:self];
    NSRect adjusted = DPEdgeToEdgeFrame(self, frame);
    DPSetCornerRadius(self, NSEqualRects(adjusted, frame) ? 0 : DPProgress[DPEdgeToEdge] * DPWindowPadding);
    DPCallOriginal(void (*)(id, SEL, NSRect), self, _cmd, adjusted);
}

// Scales the corners of the path's first subpath in place; same elements, so Dia's path animations still interpolate.
static CGPathRef DPReshapeCorners(CGPathRef path, CGFloat extent, CGFloat rightScale, CGFloat leftScale) {
    if (!path) return NULL;
    __block CGRect box = CGRectNull;
    __block int subpath = 0;
    CGPathApplyWithBlock(path, ^(const CGPathElement *element) {
        if (element->type == kCGPathElementMoveToPoint && !CGRectIsNull(box)) subpath++;
        int count = element->type == kCGPathElementAddCurveToPoint ? 3 : element->type == kCGPathElementAddQuadCurveToPoint ? 2
                  : element->type == kCGPathElementCloseSubpath ? 0 : 1;
        for (int i = 0; i < count && subpath == 0; i++) box = CGRectUnion(box, (CGRect){element->points[i], CGSizeZero});
    });
    CGMutablePathRef reshaped = CGPathCreateMutable();
    subpath = 0;
    __block BOOL started = NO;
    CGPoint (^move)(CGPoint) = ^CGPoint(CGPoint p) {
        if (subpath > 0) return p;
        CGFloat cx = p.x - CGRectGetMinX(box) < extent ? CGRectGetMinX(box) : CGRectGetMaxX(box) - p.x < extent ? CGRectGetMaxX(box) : NAN;
        CGFloat cy = p.y - CGRectGetMinY(box) < extent ? CGRectGetMinY(box) : CGRectGetMaxY(box) - p.y < extent ? CGRectGetMaxY(box) : NAN;
        if (isnan(cx) || isnan(cy)) return p;
        CGFloat scale = cx == CGRectGetMinX(box) ? leftScale : rightScale;
        return CGPointMake(cx + (p.x - cx) * scale, cy + (p.y - cy) * scale);
    };
    CGPathApplyWithBlock(path, ^(const CGPathElement *element) {
        const CGPoint *p = element->points;
        switch (element->type) {
            case kCGPathElementMoveToPoint:
                if (started) subpath++;
                started = YES;
                CGPathMoveToPoint(reshaped, NULL, move(p[0]).x, move(p[0]).y);
                break;
            case kCGPathElementAddLineToPoint: CGPathAddLineToPoint(reshaped, NULL, move(p[0]).x, move(p[0]).y); break;
            case kCGPathElementAddQuadCurveToPoint:
                CGPathAddQuadCurveToPoint(reshaped, NULL, move(p[0]).x, move(p[0]).y, move(p[1]).x, move(p[1]).y);
                break;
            case kCGPathElementAddCurveToPoint:
                CGPathAddCurveToPoint(reshaped, NULL, move(p[0]).x, move(p[0]).y, move(p[1]).x, move(p[1]).y, move(p[2]).x, move(p[2]).y);
                break;
            case kCGPathElementCloseSubpath: CGPathCloseSubpath(reshaped); break;
        }
    });
    return (CGPathRef)CFAutorelease(reshaped);
}

static void DPApplySquareCorners(NSView *container) {
    NSView *content = DPFindView(container, ^BOOL(NSView *v) { return v != container && v.layer.masksToBounds && v.layer.cornerRadius > 0; });
    CALayer *layer = content.layer;
    if (!layer) return;
    layer.cornerCurve = kCACornerCurveContinuous;
    CGFloat square = NSMinX(container.frame) > DPWindowPadding + 1 && !DPChatCard(container)
        ? DPProgress[DPSquareSidebarCorners] * DPProgress[DPEdgeToEdge] : 0;
    CACornerMask left = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner, right = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (square == 0 || square == 1) {
        layer.mask = nil;
        layer.maskedCorners = square == 1 ? right : left | right;
    } else {
        CALayer *mask = layer.mask.sublayers.count == 2 ? layer.mask : [CALayer layer];
        if (mask != layer.mask) {
            for (int i = 0; i < 2; i++) {
                CALayer *half = [CALayer layer];
                half.backgroundColor = NSColor.blackColor.CGColor;
                half.cornerCurve = kCACornerCurveContinuous;
                half.maskedCorners = i ? right : left;
                [mask addSublayer:half];
            }
        }
        CGRect bounds = layer.bounds;
        CGFloat half = CGRectGetWidth(bounds) / 2;
        mask.frame = bounds;
        mask.sublayers[0].frame = CGRectMake(0, 0, half + 1, CGRectGetHeight(bounds));
        mask.sublayers[1].frame = CGRectMake(half - 1, 0, half + 1, CGRectGetHeight(bounds));
        mask.sublayers[0].cornerRadius = layer.cornerRadius * (1 - square);
        mask.sublayers[1].cornerRadius = layer.cornerRadius;
        layer.mask = mask;
        layer.maskedCorners = 0;
    }

    CGFloat base = [objc_getAssociatedObject(container, &DPBaseRadiusKey) doubleValue] ?: layer.cornerRadius;
    CGFloat grow = base > 0 ? layer.cornerRadius / base : 1;
    for (NSView *sub in container.subviews)
        for (CALayer *sublayer in sub.layer.sublayers) {
            CAShapeLayer *shape = [sublayer isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)sublayer
                                : [sublayer.mask isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)sublayer.mask : nil;
            if (!shape.path || CGRectGetWidth(CGPathGetBoundingBox(shape.path)) < NSWidth(container.bounds) * 0.9) continue;
            CGPathRef assigned = (__bridge CGPathRef)objc_getAssociatedObject(shape, &DPAssignedPathKey);
            if (!assigned || !CGPathEqualToPath(assigned, shape.path))
                objc_setAssociatedObject(shape, &DPOriginalPathKey, CFBridgingRelease(CGPathCreateCopy(shape.path)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            CGPathRef path = DPReshapeCorners((__bridge CGPathRef)objc_getAssociatedObject(shape, &DPOriginalPathKey), base * 1.6, grow, grow * (1 - square));
            if (!CGPathEqualToPath(path, shape.path)) shape.path = path;
            objc_setAssociatedObject(shape, &DPAssignedPathKey, (__bridge id)shape.path, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    [CATransaction commit];
}

static Class DPContainerClass(void) {
    static Class cls;
    return cls = cls ?: NSClassFromString(@"_TtC6Window20ContentContainerView");
}

static void DPRestyleContainer(NSView *container) {
    DPApplySquareCorners(container);
    CALayer *card = DPChatCard(container).layer;
    if (!card) return;
    if (card.cornerCurve != kCACornerCurveContinuous) card.cornerCurve = kCACornerCurveContinuous;
    NSValue *requested = objc_getAssociatedObject(container, &DPRequestedFrameKey);
    if (requested && !NSEqualRects(container.frame, requested.rectValue)) container.frame = requested.rectValue;
}

// Dia restyles its layers after its own layout pass.
static void DPContainer_layoutOrUpdateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    DPRestyleContainer(self);
    dispatch_async(dispatch_get_main_queue(), ^{ DPRestyleContainer(self); });
}

// Opening or closing Chat reshapes the content without resizing the container.
static void DPShadow_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    NSView *container = self;
    while (container && ![container isKindOfClass:DPContainerClass()]) container = container.superview;
    if (!container) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL chat = DPChatCard(container) != nil;
        if ([objc_getAssociatedObject(container, &DPChatKey) boolValue] != chat) {
            objc_setAssociatedObject(container, &DPChatKey, @(chat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSValue *requested = objc_getAssociatedObject(container, &DPRequestedFrameKey);
            if (requested) container.frame = requested.rectValue;
        }
        DPRestyleContainer(container);
    });
}

#pragma mark - Toolbar

static NSRect DPLaidOutFrame(NSView *view) {
    NSValue *assigned = objc_getAssociatedObject(view, &DPAssignedFrameKey);
    if (assigned && NSEqualRects(assigned.rectValue, view.frame))
        return [objc_getAssociatedObject(view, &DPRequestedFrameKey) rectValue];
    return view.frame;
}

static void DPAssignFrame(NSView *view, NSRect laidOut, NSRect frame) {
    objc_setAssociatedObject(view, &DPRequestedFrameKey, [NSValue valueWithRect:laidOut], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &DPAssignedFrameKey, [NSValue valueWithRect:frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.frame = frame;
}

static Class DPToolbarClass(void) {
    static Class cls;
    return cls = cls ?: NSClassFromString(@"_TtC13NavigationBar17NavigationBarView");
}

// A hidden toolbar floats back over the page while the pointer is at the top edge or the address is being edited.
// It's lifted with zPosition rather than reordered: moving the bar in the view tree would take focus from the address.
static BOOL DPToolbarRevealed, DPRevealAnimating;

static BOOL DPToolbarHidden(void) { return DPOn[DPHideToolbar] && !DPToolbarRevealed; }

// The bar stays in Dia's layout: hiding it makes Dia reflow in ways it won't undo.
// Little Dia always shows its toolbar: the address there is the preview's header.
static BOOL DPInLittle(NSView *view) { return [DPLittleWindows containsObject:view.window]; }

static NSView *DPToolbar_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    return DPToolbarHidden() && !DPInLittle(self) ? nil : DPCallOriginal(NSView *(*)(id, SEL, NSPoint), self, _cmd, point);
}

static NSView *DPToolbarIn(NSView *pane) {
    for (NSView *sub in pane.subviews) if ([sub isKindOfClass:DPToolbarClass()]) return sub;
    return nil;
}

// The bar's own background is see-through, so a floating bar needs something behind it.
@interface DPBackdropView : NSVisualEffectView
@end
@implementation DPBackdropView
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end

static NSVisualEffectView *DPBackdrop(NSView *pane) {
    NSVisualEffectView *backdrop = objc_getAssociatedObject(pane, &DPBackdropKey);
    if (backdrop.superview == pane) return backdrop;
    backdrop = backdrop ?: [DPBackdropView new];
    backdrop.material = NSVisualEffectMaterialHeaderView;
    backdrop.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    backdrop.state = NSVisualEffectStateActive;
    backdrop.wantsLayer = YES;
    backdrop.alphaValue = 0;
    [pane addSubview:backdrop];
    backdrop.layer.zPosition = 1;
    objc_setAssociatedObject(pane, &DPBackdropKey, backdrop, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return backdrop;
}

// The lifted bar is drawn above the page but still sits under it in the view tree, so clicks are routed to it.
static NSView *DPPane_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    NSView *bar = DPOn[DPHideToolbar] && DPToolbarRevealed ? DPToolbarIn(self) : nil;
    NSPoint local = [self convertPoint:point fromView:self.superview];
    NSView *hit = bar && NSPointInRect(local, bar.frame) ? [bar hitTest:local] : nil;
    return hit ?: DPCallOriginal(NSView *(*)(id, SEL, NSPoint), self, _cmd, point);
}

static void DPApplyToolbar(NSView *pane) {
    NSView *bar = DPToolbarIn(pane);
    if (!bar) return;

    CGFloat progress = DPInLittle(pane) ? 0 : DPProgress[DPHideToolbar];
    NSVisualEffectView *backdrop = DPBackdrop(pane);
    backdrop.frame = bar.frame;
    backdrop.hidden = progress < 1;
    if (progress < 1) {
        bar.alphaValue = 1 - progress;
        bar.layer.zPosition = 0;
    } else if (!DPRevealAnimating) {
        // Dia's own layout passes can reset these, so they're reapplied after each one.
        bar.alphaValue = backdrop.alphaValue = DPToolbarRevealed;
        bar.layer.zPosition = DPToolbarRevealed ? 2 : 0;
    }
    NSView *lowest = pane.subviews.firstObject;
    if (progress > 0 && lowest != bar) [pane addSubview:bar positioned:NSWindowBelow relativeTo:lowest];
    else if (progress == 0 && lowest == bar) [pane addSubview:bar positioned:NSWindowAbove relativeTo:nil];

    BOOL flipped = pane.isFlipped;
    CGFloat (^top)(NSRect) = ^CGFloat(NSRect r) { return flipped ? NSMinY(r) : NSHeight(pane.bounds) - NSMaxY(r); };
    CGFloat (^bottom)(NSRect) = ^CGFloat(NSRect r) { return flipped ? NSMaxY(r) : NSHeight(pane.bounds) - NSMinY(r); };
    CGFloat shift = NSHeight(bar.frame) * progress, edge = bottom(bar.frame);
    NSMutableArray<NSView *> *stack = [NSMutableArray new];
    for (NSView *sub in pane.subviews) if (sub != bar && sub != backdrop) [stack addObject:sub];
    [stack sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        return [@(top(DPLaidOutFrame(a))) compare:@(top(DPLaidOutFrame(b)))];
    }];
    for (NSView *view in stack) {
        NSRect laidOut = DPLaidOutFrame(view);
        if (fabs(top(laidOut) - edge) > 0.5) continue;
        BOOL reachesBottom = fabs(bottom(laidOut) - NSHeight(pane.bounds)) < 0.5;
        if (!reachesBottom) edge = bottom(laidOut);
        NSRect frame = laidOut;
        if (reachesBottom) frame.size.height += shift;
        if (flipped) frame.origin.y -= shift;
        else if (!reachesBottom) frame.origin.y += shift;
        DPAssignFrame(view, laidOut, frame);
        // Dia sizes the web view once instead of autoresizing it.
        for (NSView *child in view.subviews) {
            if (!objc_getAssociatedObject(child, &DPFillsKey)) {
                if (!NSEqualRects(child.frame, (NSRect){NSZeroPoint, laidOut.size})) continue;
                objc_setAssociatedObject(child, &DPFillsKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            child.frame = view.bounds;
        }
    }
}

static void DPPane_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    [DPPanes addObject:self];
    DPApplyToolbar(self);
}

#pragma mark - Animation

static void DPRelayout(void) {
    for (NSView *container in DPContainers) {
        NSValue *requested = objc_getAssociatedObject(container, &DPRequestedFrameKey);
        if (requested) container.frame = requested.rectValue;
        container.needsLayout = container.needsDisplay = YES;
        DPRestyleContainer(container);
    }
    for (NSView *pane in DPPanes) {
        pane.needsLayout = YES;
        [pane layoutSubtreeIfNeeded];
    }
}

static void DPAnimate(void) {
    static NSTimer *timer;
    static CFTimeInterval start;
    static CGFloat from[DPAnimatedCount];
    start = CACurrentMediaTime();
    for (int i = 0; i < DPAnimatedCount; i++) from[i] = DPProgress[i];
    if (timer) return;
    timer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *t) {
        CGFloat elapsed = CACurrentMediaTime() - start, omega = 22;
        BOOL done = elapsed >= DPAnimationDuration * 2;
        CGFloat eased = done ? 1 : 1 - (1 + omega * elapsed) * exp(-omega * elapsed);
        for (int i = 0; i < DPAnimatedCount; i++) DPProgress[i] = from[i] + (DPOn[i] - from[i]) * eased;
        DPRelayout();
        if (done) {
            [t invalidate];
            timer = nil;
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

#pragma mark - Toolbar reveal

static const CGFloat DPRevealEdge = 6, DPRevealMargin = 12;
static const NSTimeInterval DPRevealPollInterval = 1.0 / 30, DPHideDelay = 0.4, DPShowDuration = 0.16, DPHideDuration = 0.22;

static BOOL DPEditingIn(NSView *bar) {
    id responder = bar.window.firstResponder;
    if ([responder isKindOfClass:NSText.class] && [responder isFieldEditor]) responder = [responder delegate];
    return [responder isKindOfClass:NSView.class] && [responder isDescendantOf:bar];
}

static NSRect DPScreenRect(NSView *view) {
    return [view.window convertRectToScreen:[view convertRect:view.bounds toView:nil]];
}

// Polled from NSEvent.mouseLocation rather than mouse events, which pages and other windows can swallow.
static BOOL DPWantsToolbar(void) {
    NSPoint mouse = NSEvent.mouseLocation;
    NSInteger under = [NSWindow windowNumberAtPoint:mouse belowWindowWithWindowNumber:0];
    NSWindow *underWindow = [NSApp windowWithWindowNumber:under];
    for (NSView *pane in DPPanes) {
        NSView *bar = DPToolbarIn(pane);
        NSWindow *window = pane.window;
        if (!bar || !window.isVisible || pane.isHiddenOrHasHiddenAncestor || DPInLittle(pane)) continue;
        // The window under an open Little Dia is dimmed and only there to be clicked back to.
        if (window.childWindows.count && [DPLittleWindows containsObject:window.childWindows.lastObject] && window.childWindows.lastObject.isVisible) continue;
        if (DPEditingIn(bar)) return YES;
        // Address suggestions, menus and popovers open from the bar in windows of their own.
        if (DPToolbarRevealed && underWindow && underWindow != window
            && (underWindow.parentWindow == window || underWindow.level > window.level)) return YES;
        NSRect paneRect = DPScreenRect(pane), barRect = DPScreenRect(bar), frame = window.frame;
        if (mouse.x < NSMinX(paneRect) || mouse.x > NSMaxX(paneRect)) continue;
        // A window flush under the menu bar also reveals from the menu bar, so the pointer can be thrown at the edge.
        BOOL overWindow = window.windowNumber == under && mouse.y <= NSMaxY(paneRect) + 2 * DPWindowPadding;
        BOOL pastTop = mouse.y >= NSMaxY(frame) && mouse.y <= NSMaxY(window.screen.frame)
                    && NSMaxY(frame) >= NSMaxY(window.screen.visibleFrame) - 1;
        if (!overWindow && !pastTop) continue;
        if (mouse.y >= (DPToolbarRevealed ? NSMinY(barRect) - DPRevealMargin : NSMaxY(paneRect) - DPRevealEdge)) return YES;
    }
    return NO;
}

static void DPSetToolbarRevealed(BOOL revealed) {
    static NSUInteger generation;
    if (DPToolbarRevealed == revealed) return;
    DPToolbarRevealed = revealed;
    if (DPProgress[DPHideToolbar] < 1) return;
    NSUInteger current = ++generation;
    DPRevealAnimating = YES;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = revealed ? DPShowDuration : DPHideDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:revealed ? kCAMediaTimingFunctionEaseOut : kCAMediaTimingFunctionEaseInEaseOut];
        for (NSView *pane in DPPanes) {
            NSView *bar = DPToolbarIn(pane);
            if (!bar) continue;
            NSVisualEffectView *backdrop = DPBackdrop(pane);
            backdrop.frame = bar.frame;
            if (revealed) bar.layer.zPosition = 2;
            bar.animator.alphaValue = revealed;
            backdrop.animator.alphaValue = revealed;
        }
    } completionHandler:^{
        if (current != generation) return;
        DPRevealAnimating = NO;
        for (NSView *pane in DPPanes) DPToolbarIn(pane).layer.zPosition = DPToolbarRevealed ? 2 : 0;
    }];
}

static void DPPollToolbarReveal(void) {
    static CFTimeInterval lastWanted;
    CFTimeInterval now = CACurrentMediaTime();
    // Mid-drag or while a menu is open, the toolbar stays as it is.
    if (NSEvent.pressedMouseButtons || [NSRunLoop.currentRunLoop.currentMode isEqualToString:NSEventTrackingRunLoopMode]) {
        lastWanted = now;
        return;
    }
    if (DPWantsToolbar()) {
        lastWanted = now;
        DPSetToolbarRevealed(YES);
    } else if (now - lastWanted >= DPHideDelay) DPSetToolbarRevealed(NO);
}

static void DPUpdateRevealPolling(void) {
    static NSTimer *timer;
    if (DPOn[DPHideToolbar] && !timer) {
        timer = [NSTimer timerWithTimeInterval:DPRevealPollInterval repeats:YES block:^(NSTimer *_) { DPPollToolbarReveal(); }];
        timer.tolerance = DPRevealPollInterval / 2;
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    } else if (!DPOn[DPHideToolbar] && timer) {
        [timer invalidate];
        timer = nil;
    }
}

#pragma mark - Scrollbars

// Dia's native views and its web pages both follow AppKit's preferred style, so overlay
// scrollbars float over content without a gutter even with a mouse connected.
static NSScrollerStyle DPScroller_preferredScrollerStyle(id self, SEL _cmd) {
    return DPOn[DPOverlayScrollbars] ? NSScrollerStyleOverlay : DPCallOriginal(NSScrollerStyle (*)(id, SEL), self, _cmd);
}

#pragma mark - Little Dia

// A small window for links from other apps and quick look-ups, like Arc's Little Arc. It's an ordinary Dia window
// made through Dia's own AppleScript support, so pages share the profile's sign-ins.
static const NSSize DPLittleSize = {860, 640};
static const NSTimeInterval DPLittleReadyPoll = 1.0 / 60, DPLittleReadyTimeout = 0.6, DPLittleLoadPoll = 0.05, DPLittleLoadTimeout = 1,
                            DPLittleLoadStartGrace = 0.4, DPLittleShowWhileLoading = 0.35, DPLittlePaintDelay = 0.08, DPLittleFadeDuration = 0.2,
                            DPLittleShimmerDuration = 1.1;
static const CGFloat DPLittleCornerRadius = 12, DPLittleOriginWidth = 160, DPLittlePopScale = 0.92;
// A touch under critical damping: it lands quickly with a barely visible settle.
static const CGFloat DPSpringMass = 1, DPSpringStiffness = 240, DPSpringDamping = 27;
static const UInt32 DPLittleHotKeySignature = 0x44506C64;
// There's one Little Dia, kept hidden between uses like Arc's Peek: reusing it skips the 0.7s Dia takes to make a window.
static __weak NSWindow *DPLittle;
static BOOL DPLaunched, DPLittleOpening;
static const NSTimeInterval DPLittleHideDuration = 0.15, DPScrimDuration = 0.2;
static NSString *const DPLittleWindowIDKey = @"littleWindowID";
static const NSTimeInterval DPLeftoverPoll = 0.5;
static const int DPLeftoverAttempts = 20;
static const CGFloat DPPopoverWidthFraction = 0.82, DPPopoverHeightFraction = 0.86, DPPopoverMaxWidth = 1200, DPScrimOpacity = 0.25;
static NSView *DPScrim;

static NSString *DPQuoted(NSString *text) {
    text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    return [NSString stringWithFormat:@"\"%@\"", [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
}

// Events sent to Dia itself are handled in-process, so this needs no Automation permission.
static NSAppleEventDescriptor *DPDiaScript(NSString *body) {
    NSString *source = [NSString stringWithFormat:@"tell application id %@\n%@\nend tell", DPQuoted(NSBundle.mainBundle.bundleIdentifier), body];
    NSDictionary *error = nil;
    NSAppleEventDescriptor *result = [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
    if (!result) NSLog(@"DiaPatches: Little Dia script failed: %@", error);
    return result;
}

static NSString *DPLittleID(NSWindow *window) { return objc_getAssociatedObject(window, &DPLittleIDKey); }

static NSView *DPSidebarHeader(NSWindow *window) {
    NSView *header = DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, @"_TtC10TabSidebar17SidebarHeaderView"); });
    if (!header || header.isHiddenOrHasHiddenAncestor) return nil;
    NSRect frame = [header convertRect:header.bounds toView:nil];
    return NSWidth(frame) < 1 || NSMaxX(frame) <= 1 ? nil : header;
}

// Sent up the sidebar's own responder chain, so it works before the window becomes key.
static void DPCollapseSidebar(NSWindow *window) {
    NSView *header = DPSidebarHeader(window);
    SEL toggle = NSSelectorFromString(@"toggleSidebar:");
    if (header && ![header tryToPerform:toggle with:nil] && window.isKeyWindow) [NSApp sendAction:toggle to:nil from:nil];
}

static BOOL DPLittleAlive(NSWindow *window) {
    return window && DPLittleID(window) && [NSApp.windows containsObject:window];
}

static void DPHideLittle(NSWindow *window);

// Dims the window Little Dia opened over; a click on it dismisses Little Dia, like clicking outside a popover.
@interface DPScrimView : NSView
@end

@implementation DPScrimView
- (NSView *)hitTest:(NSPoint)point { return NSPointInRect([self convertPoint:point fromView:self.superview], self.bounds) ? self : nil; }
- (void)mouseDown:(NSEvent *)event { DPHideLittle(DPLittle); }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
@end

// The window Little Dia opens over: the one in use, or Dia's frontmost when a link comes from another app.
static NSWindow *DPLittleParent(void) {
    NSMutableArray<NSWindow *> *candidates = [NSMutableArray arrayWithObject:NSApp.mainWindow ?: NSNull.null];
    [candidates addObjectsFromArray:NSApp.orderedWindows];
    for (id window in candidates)
        if ([window isKindOfClass:NSWindow.class] && [window canBecomeMainWindow] && [window isVisible] && ![window isMiniaturized]
            && ![DPLittleWindows containsObject:window]) return window;
    return nil;
}

static void DPShowScrim(NSWindow *parent) {
    NSView *frame = parent.contentView.superview;
    if (!frame) return;
    if (!DPScrim) {
        DPScrim = [DPScrimView new];
        DPScrim.wantsLayer = YES;
        DPScrim.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:DPScrimOpacity].CGColor;
        DPScrim.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    DPScrim.frame = frame.bounds;
    DPScrim.alphaValue = 0;
    [frame addSubview:DPScrim positioned:NSWindowAbove relativeTo:nil];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPScrimDuration;
        DPScrim.animator.alphaValue = 1;
    }];
}

// A child window rides along with the window it opened over and isn't listed as a window of its own.
static void DPAttachLittle(NSWindow *window, NSWindow *parent) {
    for (NSWindowButton type = NSWindowCloseButton; type <= NSWindowZoomButton; type++) [window standardWindowButton:type].hidden = YES;
    if (!parent) return;
    if (window.parentWindow != parent) {
        [window.parentWindow removeChildWindow:window];
        [parent addChildWindow:window ordered:NSWindowAbove];
    }
    DPShowScrim(parent);
}

// Hidden rather than closed, and emptied so nothing keeps playing behind the scenes.
static void DPHideLittle(NSWindow *window) {
    if (!DPLittleAlive(window) || !window.isVisible || DPLittleOpening) return;
    NSString *windowID = DPLittleID(window);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = DPLittleHideDuration;
        window.animator.alphaValue = 0;
        DPScrim.animator.alphaValue = 0;
    } completionHandler:^{
        if (DPLittleOpening) return;
        [DPScrim removeFromSuperview];
        [window.parentWindow removeChildWindow:window];
        [window orderOut:nil];
        DPDiaScript([NSString stringWithFormat:@"set URL of active tab of window id %@ to \"about:blank\"", DPQuoted(windowID)]);
    }];
}

static void DPMoveToDia(NSWindow *little) {
    NSString *littleID = DPLittleID(little);
    if (!littleID) return;
    NSMutableArray<NSString *> *ids = [NSMutableArray new];
    for (NSWindow *window in DPLittleWindows) if (DPLittleID(window)) [ids addObject:DPQuoted(DPLittleID(window))];
    // Windows are listed front to back, so the first one that isn't little is the one last used.
    DPDiaScript([NSString stringWithFormat:@
        "set lw to window id %@\n"
        "set u to URL of active tab of lw\n"
        "set target to missing value\n"
        "repeat with w in windows\n"
        "  if {%@} does not contain (id of w) then\n"
        "    set target to contents of w\n"
        "    exit repeat\n"
        "  end if\n"
        "end repeat\n"
        "if u is missing value then\n"
        "  if target is not missing value then focus active tab of target\n"
        "else if target is missing value then\n"
        "  set URL of active tab of (make new window) to u\n"
        "else\n"
        "  focus (make new tab at end of tabs of target with properties {URL:u})\n"
        "end if",
        DPQuoted(littleID), [ids componentsJoinedByString:@", "]]);
    DPHideLittle(little);
}

@interface DPLittleTarget : NSObject
@end

@implementation DPLittleTarget
- (void)moveToDia:(NSButton *)sender { DPMoveToDia(sender.window); }
@end

static void DPAddMoveButton(NSWindow *window) {
    static DPLittleTarget *target;
    target = target ?: [DPLittleTarget new];
    NSButton *button = [NSButton buttonWithTitle:@"Open in Dia" image:[NSImage imageWithSystemSymbolName:@"arrow.up.forward.app" accessibilityDescription:nil]
                                          target:target action:@selector(moveToDia:)];
    button.bezelStyle = NSBezelStyleInline;
    button.imagePosition = NSImageLeading;
    button.controlSize = NSControlSizeSmall;
    button.toolTip = @"Open in Dia (⌘O)";
    NSVisualEffectView *pill = [NSVisualEffectView new];
    pill.material = NSVisualEffectMaterialHUDWindow;
    pill.state = NSVisualEffectStateActive;
    pill.wantsLayer = YES;
    pill.layer.cornerRadius = 12;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.masksToBounds = YES;
    [pill addSubview:button];
    NSView *content = window.contentView;
    [content addSubview:pill];
    for (NSView *v in @[pill, button]) v.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:4],
        [button.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-4],
        [button.topAnchor constraintEqualToAnchor:pill.topAnchor constant:2],
        [button.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-2],
        [pill.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [pill.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
    ]];
}

// A window-shaped card springs from the link to where Little Dia will be, while Dia builds the real window
// underneath. Core Animation runs it out of process, so it stays smooth while Dia is busy creating the window.
@interface DPLittleTransition : NSObject
@property (nonatomic) NSWindow *overlay, *window;
@property (nonatomic) NSString *windowID;
@property (nonatomic) NSURL *url;
@property (nonatomic) CALayer *card;
@property (nonatomic) BOOL landed, ready;
@end

@implementation DPLittleTransition

static NSMutableSet<DPLittleTransition *> *DPTransitions;

static CASpringAnimation *DPSpring(NSString *keyPath, id from, id to) {
    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:keyPath];
    spring.mass = DPSpringMass;
    spring.stiffness = DPSpringStiffness;
    spring.damping = DPSpringDamping;
    spring.fromValue = from;
    spring.toValue = to;
    spring.duration = spring.settlingDuration;
    return spring;
}

- (instancetype)initFrom:(NSPoint)origin scale:(CGFloat)scale to:(NSRect)frame on:(NSScreen *)screen label:(NSString *)label {
    if (!(self = [super init])) return nil;
    _overlay = [[NSWindow alloc] initWithContentRect:screen.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    _overlay.releasedWhenClosed = NO;
    _overlay.opaque = NO;
    _overlay.backgroundColor = NSColor.clearColor;
    _overlay.hasShadow = NO;
    _overlay.ignoresMouseEvents = YES;
    _overlay.level = NSFloatingWindowLevel;
    _overlay.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorFullScreenAuxiliary;
    NSView *root = _overlay.contentView;
    root.wantsLayer = YES;

    CALayer *card = _card = [CALayer layer];
    card.frame = NSOffsetRect(frame, -NSMinX(screen.frame), -NSMinY(screen.frame));
    card.cornerRadius = DPLittleCornerRadius;
    card.cornerCurve = kCACornerCurveContinuous;
    card.borderWidth = 0.5;
    card.shadowOpacity = 0.28;
    card.shadowRadius = 24;
    card.shadowOffset = CGSizeMake(0, -10);
    CATextLayer *text = [CATextLayer layer];
    text.string = label ?: @"";
    text.fontSize = 13;
    text.alignmentMode = kCAAlignmentCenter;
    text.contentsScale = screen.backingScaleFactor;
    text.frame = CGRectMake(0, CGRectGetHeight(card.bounds) / 2 - 9, CGRectGetWidth(card.bounds), 18);
    [NSApp.effectiveAppearance performAsCurrentDrawingAppearance:^{
        card.backgroundColor = NSColor.windowBackgroundColor.CGColor;
        card.borderColor = NSColor.separatorColor.CGColor;
        text.foregroundColor = NSColor.secondaryLabelColor.CGColor;
    }];
    [card addSublayer:text];
    // A thin bar sweeps along the top while the page loads behind the card.
    if (label) {
        CAGradientLayer *shimmer = [CAGradientLayer layer];
        shimmer.frame = CGRectMake(DPLittleCornerRadius, CGRectGetHeight(card.bounds) - 2, CGRectGetWidth(card.bounds) - 2 * DPLittleCornerRadius, 2);
        shimmer.startPoint = CGPointMake(0, 0.5);
        shimmer.endPoint = CGPointMake(1, 0.5);
        NSColor *accent = NSColor.controlAccentColor;
        shimmer.colors = @[(__bridge id)[accent colorWithAlphaComponent:0].CGColor, (__bridge id)accent.CGColor, (__bridge id)[accent colorWithAlphaComponent:0].CGColor];
        CABasicAnimation *sweep = [CABasicAnimation animationWithKeyPath:@"locations"];
        sweep.fromValue = @[@-0.3, @-0.15, @0];
        sweep.toValue = @[@1, @1.15, @1.3];
        sweep.duration = DPLittleShimmerDuration;
        sweep.repeatCount = HUGE_VALF;
        sweep.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [shimmer addAnimation:sweep forKey:@"sweep"];
        [card addSublayer:shimmer];
    }
    [root.layer addSublayer:card];

    // A uniform scale keeps the corners and label in proportion, so it reads as the window zooming out.
    NSPoint start = NSMakePoint(origin.x - NSMinX(screen.frame), origin.y - NSMinY(screen.frame));
    CASpringAnimation *move = DPSpring(@"position", [NSValue valueWithPoint:start], [NSValue valueWithPoint:NSPointFromCGPoint(card.position)]);
    CASpringAnimation *grow = DPSpring(@"transform.scale", @(scale), @1);
    CABasicAnimation *appear = [CABasicAnimation animationWithKeyPath:@"opacity"];
    appear.fromValue = @0;
    appear.duration = 0.08;
    [card addAnimation:move forKey:@"move"];
    [card addAnimation:grow forKey:@"grow"];
    [card addAnimation:appear forKey:@"appear"];
    [_overlay orderFrontRegardless];
    [CATransaction flush];

    [DPTransitions addObject:self];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(move.duration, grow.duration) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.landed = YES;
        [self finish];
    });
    return self;
}

- (void)windowReady:(NSWindow *)window id:(NSString *)windowID url:(NSURL *)url {
    self.window = window;
    self.windowID = windowID;
    self.url = url;
    self.ready = YES;
    [self finish];
}

// Once the card covers the window's final frame, the window is shown under it: Dia doesn't draw pages in a
// transparent window, and revealing one before it has painted shows black.
- (void)finish {
    if (!self.landed || !self.ready) return;
    self.window.alphaValue = 1;
    if (!self.url) {
        [self revealAfterPaint];
        return;
    }
    CFTimeInterval start = CACurrentMediaTime();
    __block CFTimeInterval started = 0;
    NSString *script = [NSString stringWithFormat:@"set t to active tab of window id %@\nreturn {URL of t, loading of t}", DPQuoted(self.windowID)];
    [NSTimer scheduledTimerWithTimeInterval:DPLittleLoadPoll repeats:YES block:^(NSTimer *timer) {
        CFTimeInterval elapsed = CACurrentMediaTime() - start;
        NSAppleEventDescriptor *state = self.window.isVisible ? DPDiaScript(script) : nil;
        BOOL loading = [state descriptorAtIndex:2].booleanValue;
        if (loading && !started) started = CACurrentMediaTime();
        // The tab can report idle before its navigation starts, so idle only counts once it has loaded or had a moment to.
        // A slow page is shown while it's still loading, the way a tab would show it, rather than kept behind the card.
        NSString *current = [state descriptorAtIndex:1].stringValue;
        BOOL navigated = current && ![current isEqualToString:@"about:blank"];
        BOOL loaded = navigated && !loading && (started || elapsed > DPLittleLoadStartGrace);
        BOOL underway = started && CACurrentMediaTime() - started > DPLittleShowWhileLoading;
        if (!loaded && !underway && state && elapsed < DPLittleLoadTimeout) return;
        [timer invalidate];
        [self revealAfterPaint];
    }];
}

- (void)revealAfterPaint {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DPLittlePaintDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = DPLittleFadeDuration;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            self.overlay.animator.alphaValue = 0;
        } completionHandler:^{
            [self.overlay orderOut:nil];
            [DPTransitions removeObject:self];
        }];
    });
}

- (void)cancel {
    [self.overlay orderOut:nil];
    [DPTransitions removeObject:self];
}

@end

// Reveals the window once Dia has finished collapsing its sidebar, or after a moment if it never reports back.
static void DPWhenLittleReady(NSWindow *window, NSString *windowID, NSURL *url, NSRect frame, DPLittleTransition *transition) {
    CFTimeInterval start = CACurrentMediaTime();
    [NSTimer scheduledTimerWithTimeInterval:DPLittleReadyPoll repeats:YES block:^(NSTimer *timer) {
        if (!NSEqualRects(window.frame, frame)) [window setFrame:frame display:YES];
        if (DPSidebarHeader(window) && CACurrentMediaTime() - start < DPLittleReadyTimeout) return;
        [timer invalidate];
        DPLittleOpening = NO;
        [transition windowReady:window id:windowID url:url];
    }];
}

// Collects windows Dia creates while making a little window. They start out invisible: Dia orders new windows in
// through paths that skip the public ordering methods, so hiding at creation is the only way no frame of the
// full-size window, sidebar open, reaches the screen. Anything else made meanwhile, like a tooltip, is restored.
static NSMutableArray<NSWindow *> *DPWindowsMadeForLittle;

static id DPWindow_init(NSWindow *self, SEL _cmd, NSRect rect, NSWindowStyleMask style, NSBackingStoreType backing, BOOL defer, NSScreen *screen) {
    NSWindow *window = DPCallOriginal(id (*)(id, SEL, NSRect, NSWindowStyleMask, NSBackingStoreType, BOOL, id), self, _cmd, rect, style, backing, defer, screen);
    if (window && DPWindowsMadeForLittle) {
        window.alphaValue = 0;
        [DPWindowsMadeForLittle addObject:window];
    }
    return window;
}

// Swift subclasses may come in through either designated initializer.
static id DPWindow_initNoScreen(NSWindow *self, SEL _cmd, NSRect rect, NSWindowStyleMask style, NSBackingStoreType backing, BOOL defer) {
    NSWindow *window = DPCallOriginal(id (*)(id, SEL, NSRect, NSWindowStyleMask, NSBackingStoreType, BOOL), self, _cmd, rect, style, backing, defer);
    if (window && DPWindowsMadeForLittle) {
        window.alphaValue = 0;
        if (![DPWindowsMadeForLittle containsObject:window]) [DPWindowsMadeForLittle addObject:window];
    }
    return window;
}

// From the pointer for links, since that's where the click was; a small pop from the centre for the shortcut.
static void DPOpenLittleDia(NSURL *url, BOOL fromPointer, void (^fallback)(void)) {
    NSPoint mouse = NSEvent.mouseLocation;
    NSWindow *parent = DPLittleParent();
    NSScreen *screen = parent.screen ?: NSScreen.mainScreen;
    if (!parent) for (NSScreen *s in NSScreen.screens) if (NSMouseInRect(mouse, s.frame, NO)) screen = s;
    // Over the window in use, like a popover; centred on the screen when Dia has no window to open over.
    NSRect area = parent ? parent.frame : screen.visibleFrame;
    NSSize size = parent ? NSMakeSize(MIN(round(NSWidth(area) * DPPopoverWidthFraction), DPPopoverMaxWidth), round(NSHeight(area) * DPPopoverHeightFraction))
                         : NSMakeSize(MIN(DPLittleSize.width, NSWidth(area) - 40), MIN(DPLittleSize.height, NSHeight(area) - 40));
    NSRect frame = NSMakeRect(round(NSMidX(area) - size.width / 2), round(NSMidY(area) - size.height / 2), size.width, size.height);
    NSPoint origin = fromPointer ? mouse : NSMakePoint(NSMidX(frame), NSMidY(frame));
    CGFloat scale = fromPointer ? DPLittleOriginWidth / size.width : DPLittlePopScale;
    DPLittleTransition *transition = [[DPLittleTransition alloc] initFrom:origin scale:scale to:frame on:screen label:url.host];

    // On the next turn, so the card is already moving while Dia builds the window.
    dispatch_async(dispatch_get_main_queue(), ^{
        DPLittleOpening = YES;
        // A link loads into the hidden Little Dia. The shortcut wants Dia's New Tab page, which only a new window opens on.
        NSWindow *reuse = DPLittle;
        if (url && DPLittleAlive(reuse)
            && DPDiaScript([NSString stringWithFormat:@"set URL of active tab of window id %@ to %@", DPQuoted(DPLittleID(reuse)), DPQuoted(url.absoluteString)])) {
            reuse.alphaValue = 0;
            [reuse setFrame:frame display:YES];
            DPAttachLittle(reuse, parent);
            [NSApp activateIgnoringOtherApps:YES];
            [reuse makeKeyAndOrderFront:nil];
            DPWhenLittleReady(reuse, DPLittleID(reuse), url, frame, transition);
            return;
        }
        for (NSWindow *old in DPLittleWindows.allObjects)
            if (DPLittleID(old)) DPDiaScript([NSString stringWithFormat:@"close window id %@", DPQuoted(DPLittleID(old))]);

        NSSet<NSWindow *> *before = [NSSet setWithArray:NSApp.windows];
        DPWindowsMadeForLittle = [NSMutableArray new];
        NSString *body = url ? [NSString stringWithFormat:@"set w to make new window\nset URL of active tab of w to %@\nreturn id of w", DPQuoted(url.absoluteString)]
                             : @"return id of (make new window)";
        NSString *windowID = DPDiaScript(body).stringValue;
        NSWindow *window = nil;
        for (NSWindow *w in NSApp.windows) if (![before containsObject:w] && w.canBecomeMainWindow) { window = w; break; }
        for (NSWindow *w in DPWindowsMadeForLittle) if (w != window) w.alphaValue = 1;
        DPWindowsMadeForLittle = nil;
        if (!windowID || !window) {
            DPLittleOpening = NO;
            [transition cancel];
            if (fallback) fallback();
            return;
        }
        window.alphaValue = 0;
        objc_setAssociatedObject(window, &DPLittleIDKey, windowID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [DPLittleWindows addObject:window];
        DPLittle = window;
        [DPDefaults setObject:windowID forKey:DPLittleWindowIDKey];
        [window setFrame:frame display:YES];
        DPAddMoveButton(window);
        DPAttachLittle(window, parent);
        [NSApp activateIgnoringOtherApps:YES];
        [window makeKeyAndOrderFront:nil];
        DPCollapseSidebar(window);
        DPWhenLittleReady(window, windowID, url, frame, transition);
    });
}

// Links that launch Dia open as usual, since its windows are still being restored.
static BOOL DPWantsLittleDia(NSURL *url) {
    return DPOn[DPLittleDia] && DPLaunched && [@[@"http", @"https"] containsObject:url.scheme.lowercaseString];
}

// Dia takes links from other apps in its own Apple Event handler rather than application:openURLs:.
static void DPOpenURLEvent_handle(id self, SEL _cmd, NSAppleEventDescriptor *event, NSAppleEventDescriptor *reply) {
    NSString *text = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    NSURL *url = text ? [NSURL URLWithString:text] : nil;
    if (event.eventClass != kInternetEventClass || event.eventID != kAEGetURL || !DPWantsLittleDia(url)) {
        DPCallOriginal(void (*)(id, SEL, id, id), self, _cmd, event, reply);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        DPOpenLittleDia(url, YES, ^{ DPCallOriginal(void (*)(id, SEL, id, id), self, _cmd, event, reply); });
    });
}

// Dia answers a navigation with where it should open (1 this tab, 2 a new tab in front, 3 a background tab), or 0 to drop it.
static const NSInteger DPDropNavigation = 0, DPCurrentTab = 1, DPNewForegroundTab = 2;

// The registrable part of a host, close enough to tell sites apart: "docs.google.com" and "google.com" match, as do "bbc.co.uk" hosts.
static NSString *DPSite(NSString *host) {
    NSArray<NSString *> *labels = [host.lowercaseString componentsSeparatedByString:@"."];
    NSUInteger keep = labels.count >= 3 && labels.lastObject.length == 2 && labels[labels.count - 2].length <= 3 ? 3 : 2;
    keep = MIN(keep, labels.count);
    return [[labels subarrayWithRange:NSMakeRange(labels.count - keep, keep)] componentsJoinedByString:@"."];
}

// A link to another site that would open a new tab goes to Little Dia instead, like Little Arc.
// Inside Little Dia it replaces the page, so the window keeps a single tab.
static NSInteger DPWebContent_decidePolicy(id self, SEL _cmd, id webContents, id action) {
    NSInteger disposition = DPCallOriginal(NSInteger (*)(id, SEL, id, id), self, _cmd, webContents, action);
    if (!DPOn[DPLittleDia] || disposition != DPNewForegroundTab) return disposition;
    NSURL *url = [action valueForKey:@"url"];
    id page = [webContents valueForKey:@"url"];
    if ([page isKindOfClass:NSString.class]) page = [NSURL URLWithString:page];
    if (![url isKindOfClass:NSURL.class] || ![page isKindOfClass:NSURL.class] || ![@[@"http", @"https"] containsObject:url.scheme.lowercaseString]
        || !url.host || !((NSURL *)page).host || [DPSite(url.host) isEqualToString:DPSite(((NSURL *)page).host)])
        return disposition;
    if ([DPLittleWindows containsObject:NSApp.keyWindow]) return DPCurrentTab;
    dispatch_async(dispatch_get_main_queue(), ^{
        DPOpenLittleDia(url, YES, ^{
            DPDiaScript([NSString stringWithFormat:@"make new tab at end of tabs of window 1 with properties {URL:%@}", DPQuoted(url.absoluteString)]);
        });
    });
    return DPDropNavigation;
}

static OSStatus DPLittleHotKeyPressed(EventHandlerCallRef next, EventRef event, void *data) {
    dispatch_async(dispatch_get_main_queue(), ^{ DPOpenLittleDia(nil, NO, nil); });
    return noErr;
}

static void DPUpdateLittleDia(void) {
    static EventHotKeyRef hotKey;
    static BOOL handlerInstalled;
    if (DPOn[DPLittleDia] && !hotKey) {
        if (!handlerInstalled) {
            EventTypeSpec spec = {kEventClassKeyboard, kEventHotKeyPressed};
            handlerInstalled = InstallApplicationEventHandler(DPLittleHotKeyPressed, 1, &spec, NULL, NULL) == noErr;
        }
        RegisterEventHotKey(kVK_ANSI_N, cmdKey | optionKey, (EventHotKeyID){DPLittleHotKeySignature, 1}, GetApplicationEventTarget(), 0, &hotKey);
    } else if (!DPOn[DPLittleDia] && hotKey) {
        UnregisterEventHotKey(hotKey);
        hotKey = NULL;
    }
}

static void DPInstallLittleDia(void) {
    DPLittleWindows = [NSHashTable weakObjectsHashTable];
    DPTransitions = [NSMutableSet new];
    DPHook(NSWindow.class, @selector(initWithContentRect:styleMask:backing:defer:screen:), (IMP)DPWindow_init);
    DPHook(NSWindow.class, @selector(initWithContentRect:styleMask:backing:defer:), (IMP)DPWindow_initNoScreen);
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [DPLittleWindows removeObject:note.object];
    }];
    // Like Peek, Little Dia goes away once you're back in another Dia window. Switching apps leaves it be.
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSWindow *window = note.object;
        if (window != DPLittle && window.canBecomeMainWindow) DPHideLittle(DPLittle);
    }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (![DPLittleWindows containsObject:event.window]) return event;
        NSEventModifierFlags mods = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~NSEventModifierFlagCapsLock;
        BOOL command = mods == NSEventModifierFlagCommand;
        // Esc still reaches the address field, so it can cancel an edit there.
        BOOL editing = [event.window.firstResponder isKindOfClass:NSText.class];
        if (command && event.keyCode == kVK_ANSI_O) DPMoveToDia(event.window);
        else if ((command && event.keyCode == kVK_ANSI_W) || (!mods && event.keyCode == kVK_Escape && !editing)) DPHideLittle(event.window);
        else return event;
        return nil;
    }];
    DPUpdateLittleDia();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        DPLaunched = YES;
        // Dia restores windows it was showing when it quit, and isn't always quit in a way that lets Little Dia close
        // first, so the last one is looked up by ID and closed once Dia has restored its windows.
        NSString *leftover = [DPDefaults stringForKey:DPLittleWindowIDKey];
        if (!leftover) return;
        NSString *script = [NSString stringWithFormat:@"if (id of every window) contains %1$@ then\nclose window id %1$@\nreturn true\nend if\nreturn false", DPQuoted(leftover)];
        __block int attempts = 0;
        [NSTimer scheduledTimerWithTimeInterval:DPLeftoverPoll repeats:YES block:^(NSTimer *timer) {
            if (![DPDiaScript(script) booleanValue] && ++attempts < DPLeftoverAttempts) return;
            [timer invalidate];
            if ([[DPDefaults stringForKey:DPLittleWindowIDKey] isEqualToString:leftover]) [DPDefaults removeObjectForKey:DPLittleWindowIDKey];
        }];
    });
}

// Little windows would otherwise come back as full windows the next time Dia opens.
static void DPCloseLittleWindows(void) {
    for (NSWindow *window in DPLittleWindows.allObjects)
        if (DPLittleID(window)) DPDiaScript([NSString stringWithFormat:@"close window id %@", DPQuoted(DPLittleID(window))]);
}

static void DPSetTweak(DPTweak tweak, BOOL on) {
    if (DPOn[tweak] == on) return;
    DPOn[tweak] = on;
    [DPDefaults setBool:on forKey:DPKeys[tweak]];
    if (tweak == DPHideToolbar) {
        DPToolbarRevealed = NO;
        DPUpdateRevealPolling();
    }
    if (tweak == DPLittleDia) DPUpdateLittleDia();
    if (tweak < DPAnimatedCount) DPAnimate();
    else if (tweak == DPOverlayScrollbars)
        [NSNotificationCenter.defaultCenter postNotificationName:NSPreferredScrollerStyleDidChangeNotification object:nil];
    else {
        if (on) for (NSView *bar in DPBars.allObjects) DPEnforceButtons(bar);
        else DPRestoreButtons(tweak);
        DPRelayoutBars();
    }
}

#pragma mark - Updates

static NSString *DPStagedPath(void) {
    return [DPCLI().stringByDeletingLastPathComponent.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"staged/Dia.app"];
}

static void DPCheckForUpdates(void (^completion)(NSDictionary *status)) {
    DPRunCLI(@[@"update"], ^(NSString *_) {
        DPRunCLI(@[@"status", @"--json"], ^(NSString *output) {
            id status = output ? [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
            completion([status isKindOfClass:NSDictionary.class] ? status : nil);
        });
    });
}

@interface DPUpdateMenuTarget : NSObject
@end

@implementation DPUpdateMenuTarget
- (void)checkForUpdates:(id)sender {
    DPCheckForUpdates(^(NSDictionary *status) {
        NSAlert *alert = [NSAlert new];
        id staged = status[@"staged"];
        if ([staged isKindOfClass:NSString.class]) {
            alert.messageText = [NSString stringWithFormat:@"Dia %@ is ready", staged];
            alert.informativeText = @"It will be installed with your patches when you quit Dia.";
            [alert addButtonWithTitle:@"Relaunch Now"];
            [alert addButtonWithTitle:@"Later"];
            if ([alert runModal] == NSAlertFirstButtonReturn) DPHandOffAndQuit(@"apply");
        } else {
            alert.messageText = status ? @"Dia is up to date" : @"Couldn’t check for updates";
            [alert runModal];
        }
    });
}
@end

static void DPInstallUpdateMenuItem(void) {
    static DPUpdateMenuTarget *target;
    target = target ?: [DPUpdateMenuTarget new];
    for (NSMenuItem *item in NSApp.mainMenu.itemArray.firstObject.submenu.itemArray) {
        if (![item.title hasPrefix:@"Check for Updates"]) continue;
        item.target = target;
        item.action = @selector(checkForUpdates:);
    }
}

static void DPApplyStagedOnQuit(void) {
    if (![NSFileManager.defaultManager fileExistsAtPath:DPStagedPath()]) return;
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:DPCLI()];
    task.arguments = @[@"apply", @"--wait", @(getpid()).stringValue];
    [task launchAndReturnError:nil];
}

#pragma mark - Settings pane

@interface DPSolidLabel : NSTextField
@end
@implementation DPSolidLabel
- (BOOL)allowsVibrancy { return NO; }
@end

@interface DPSolidImageView : NSImageView
@end
@implementation DPSolidImageView
- (BOOL)allowsVibrancy { return NO; }
@end

static NSView *DPGroup(NSArray<NSView *> *rows) {
    NSStackView *stack = [NSStackView new];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 0;
    [rows enumerateObjectsUsingBlock:^(NSView *row, NSUInteger i, BOOL *_) {
        if (i > 0) {
            NSBox *line = [NSBox new];
            line.boxType = NSBoxSeparator;
            [stack addArrangedSubview:line];
            [line.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-24].active = YES;
        }
        [stack addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }];
    NSBox *box = [NSBox new];
    box.boxType = NSBoxCustom;
    box.borderWidth = 0;
    box.cornerRadius = 10;
    box.fillColor = [NSColor.labelColor colorWithAlphaComponent:0.04];
    box.contentViewMargins = NSZeroSize;
    box.contentView = stack;
    return box;
}

static NSView *DPRow(NSView *leading, NSView *trailing) {
    NSView *row = [NSView new];
    for (NSView *v in @[leading, trailing]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:v];
    }
    [trailing setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [NSLayoutConstraint activateConstraints:@[
        [leading.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [leading.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [leading.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],
        [trailing.leadingAnchor constraintGreaterThanOrEqualToAnchor:leading.trailingAnchor constant:12],
        [trailing.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [trailing.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

static NSTextField *DPLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    return label;
}

static NSView *DPIconTile(NSString *symbol, NSColor *color) {
    NSView *tile = [NSView new];
    tile.wantsLayer = YES;
    tile.layer.backgroundColor = color.CGColor;
    tile.layer.cornerRadius = 5;
    tile.layer.cornerCurve = kCACornerCurveContinuous;
    NSImageView *glyph = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
    glyph.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightSemibold];
    glyph.contentTintColor = NSColor.whiteColor;
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    [tile addSubview:glyph];
    [NSLayoutConstraint activateConstraints:@[
        [tile.widthAnchor constraintEqualToConstant:20],
        [tile.heightAnchor constraintEqualToConstant:20],
        [glyph.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
    ]];
    return tile;
}

static NSToolbarItemIdentifier const DPSearchItemIdentifier = @"DiaPatchesSearch";

@interface DPFlippedView : NSView
@end
@implementation DPFlippedView
- (BOOL)isFlipped { return YES; }
@end

// Always overlay, so a connected mouse or "Show scroll bars: Always" doesn't reserve a gutter.
@interface DPOverlayScrollView : NSScrollView
@end
@implementation DPOverlayScrollView
- (void)setScrollerStyle:(NSScrollerStyle)style { [super setScrollerStyle:NSScrollerStyleOverlay]; }
@end

@interface DPPaneView : NSView <NSSearchFieldDelegate>
@property (nonatomic, strong) NSArray<NSSwitch *> *toggles;
@property (nonatomic, strong) NSArray<NSArray *> *sections;  // header, group, rows
@property (nonatomic, strong) NSMapTable<NSView *, NSString *> *searchText;
@property (nonatomic, strong) NSSearchToolbarItem *searchItem;
@property (nonatomic, strong) NSTextField *noResults, *notice;
@property (nonatomic, weak) NSView *squareRow;
@property (nonatomic, strong) NSTextField *status;
@property (nonatomic, strong) NSButton *checkButton;
@property (nonatomic, strong) NSButton *relaunchButton;
- (void)updateRows;
@end

@implementation DPPaneView

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    static const struct { DPTweak tweak; __unsafe_unretained NSString *symbol, *title, *detail; } rows[] = {
        {DPEdgeToEdge, @"squareshape.squareshape.dotted", @"Edge-to-edge web content", @"Remove the padding between web pages and the window edge."},
        {DPSquareSidebarCorners, @"square", @"Square corners by the sidebar", @"Let web pages meet the sidebar with straight edges."},
        {DPHideToolbar, @"menubar.rectangle", @"Hide toolbar", @"Remove the bar with the address, navigation buttons and extensions. Point at the top edge to show it. Experimental."},
        {DPHideSidebarButton, @"sidebar.left", @"Hide sidebar button", @"Hide the sidebar toggle at the top left of the toolbar."},
        {DPHideChatButton, @"bubble.fill", @"Hide Chat button", @"Hide the Chat button at the top right of the toolbar."},
        {DPHideChatsButton, @"doc.plaintext", @"Hide Chats button", @"Hide the Chats button in the tab bar or sidebar."},
        {DPHideRecentTabsButton, @"clock.arrow.circlepath", @"Hide recent tabs button", @"Hide the recent tabs button in the tab bar or sidebar."},
        {DPOverlayScrollbars, @"scroll", @"Slim scrollbars", @"Use thin scrollbars that float over pages instead of taking up a gutter."},
        {DPLittleDia, @"macwindow", @"Little Dia", @"Open links from other apps, and new-tab links to other sites, in a small window. Press ⌥⌘N anywhere for a quick one, ⌘O to move it into Dia, and Esc to dismiss it."},
    };
    NSArray<NSColor *> *tints = @[NSColor.systemBlueColor, NSColor.systemIndigoColor, NSColor.systemGrayColor, NSColor.systemOrangeColor,
                                  NSColor.systemPurpleColor, NSColor.systemTealColor, NSColor.systemPinkColor, NSColor.systemGreenColor, NSColor.systemYellowColor];
    _searchText = [NSMapTable strongToStrongObjectsMapTable];
    NSMutableArray<NSView *> *tweakRows = [NSMutableArray new];
    NSMutableArray<NSSwitch *> *toggles = [NSMutableArray new];
    for (size_t i = 0; i < sizeof rows / sizeof *rows; i++) {
        NSStackView *text = [NSStackView stackViewWithViews:@[
            DPLabel(rows[i].title, 13, NSFontWeightRegular, NSColor.labelColor),
            DPLabel(rows[i].detail, 11, NSFontWeightRegular, NSColor.secondaryLabelColor),
        ]];
        text.orientation = NSUserInterfaceLayoutOrientationVertical;
        text.alignment = NSLayoutAttributeLeading;
        text.spacing = 2;
        NSStackView *leading = [NSStackView stackViewWithViews:@[DPIconTile(rows[i].symbol, tints[i]), text]];
        leading.spacing = 10;
        leading.alignment = NSLayoutAttributeCenterY;
        NSSwitch *toggle = [NSSwitch new];
        toggle.controlSize = NSControlSizeSmall;
        toggle.state = DPOn[rows[i].tweak];
        toggle.tag = rows[i].tweak;
        toggle.target = self;
        toggle.action = @selector(toggle:);
        [toggles addObject:toggle];
        NSView *row = DPRow(leading, toggle);
        [_searchText setObject:[NSString stringWithFormat:@"%@ %@", rows[i].title, rows[i].detail] forKey:row];
        if (rows[i].tweak == DPSquareSidebarCorners) _squareRow = row;
        [tweakRows addObject:row];
    }
    _toggles = toggles;

    _status = DPLabel(@"", 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
    _checkButton = [NSButton buttonWithTitle:@"Check for Updates" target:self action:@selector(checkForUpdates:)];
    _relaunchButton = [NSButton buttonWithTitle:@"Relaunch to Update" target:self action:@selector(relaunchToUpdate:)];
    _relaunchButton.bezelColor = NSColor.controlAccentColor;
    _relaunchButton.hidden = YES;
    NSView *updateRow = DPRow(_status, [NSStackView stackViewWithViews:@[_relaunchButton, _checkButton]]);
    NSView *restoreRow = DPRow(DPLabel(@"Restore the original Dia without patches.", 13, NSFontWeightRegular, NSColor.labelColor),
                               [NSButton buttonWithTitle:@"Restore…" target:self action:@selector(restore:)]);
    [_searchText setObject:@"Check for updates version" forKey:updateRow];
    [_searchText setObject:@"Restore the original Dia without patches uninstall" forKey:restoreRow];

    _searchItem = [[NSSearchToolbarItem alloc] initWithItemIdentifier:DPSearchItemIdentifier];
    _searchItem.searchField.delegate = self;
    _noResults = DPLabel(@"No results", 13, NSFontWeightRegular, NSColor.secondaryLabelColor);
    _notice = DPLabel(@"DiaPatches is unofficial and not affiliated with The Browser Company.", 11, NSFontWeightRegular, NSColor.tertiaryLabelColor);
    NSMutableArray<NSView *> *views = [NSMutableArray new];
    NSMutableArray<NSArray *> *sections = [NSMutableArray new];
    for (NSArray *section in @[@[@"Interface", tweakRows], @[@"Updates", @[updateRow, restoreRow]]]) {
        NSTextField *header = DPLabel(section[0], 12, NSFontWeightSemibold, NSColor.secondaryLabelColor);
        NSView *group = DPGroup(section[1]);
        [views addObjectsFromArray:@[header, group]];
        [sections addObject:@[header, group, section[1]]];
    }
    [views addObjectsFromArray:@[_noResults, _notice]];
    _sections = sections;

    NSStackView *content = [NSStackView stackViewWithViews:views];
    content.orientation = NSUserInterfaceLayoutOrientationVertical;
    content.alignment = NSLayoutAttributeLeading;
    content.spacing = 8;
    for (NSView *v in content.arrangedSubviews) [v.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    // Dia's Settings window doesn't grow, so the pane scrolls below the window's title.
    DPFlippedView *document = [DPFlippedView new];
    NSScrollView *scroll = [DPOverlayScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    scroll.verticalScroller.controlSize = NSControlSizeSmall;
    scroll.automaticallyAdjustsContentInsets = NO;
    scroll.documentView = document;
    [document addSubview:content];
    [self addSubview:scroll];
    for (NSView *v in @[content, document, scroll]) v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *fill = [content.widthAnchor constraintEqualToAnchor:document.widthAnchor constant:-48];
    fill.priority = NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.topAnchor constant:52],
        [scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [content.topAnchor constraintEqualToAnchor:document.topAnchor constant:20],
        [content.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-20],
        [content.centerXAnchor constraintEqualToAnchor:document.centerXAnchor],
        [content.widthAnchor constraintLessThanOrEqualToConstant:560],
        fill,
    ]];
    [self updateRows];
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer { self.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor; }

// Unhandled events would reach Dia's pane underneath via the responder chain.
- (void)mouseDown:(NSEvent *)event {}
- (void)mouseDragged:(NSEvent *)event {}
- (void)mouseUp:(NSEvent *)event {}
- (void)rightMouseDown:(NSEvent *)event {}
- (void)rightMouseUp:(NSEvent *)event {}
- (void)otherMouseDown:(NSEvent *)event {}
- (void)otherMouseUp:(NSEvent *)event {}
- (void)scrollWheel:(NSEvent *)event {}
- (NSMenu *)menuForEvent:(NSEvent *)event { return nil; }

- (BOOL)matches:(NSView *)row words:(NSArray<NSString *> *)words {
    NSString *text = [self.searchText objectForKey:row];
    for (NSString *word in words) if (word.length && ![text localizedStandardContainsString:word]) return NO;
    return YES;
}

- (void)updateRows {
    NSString *query = self.searchItem.searchField.stringValue;
    NSArray<NSString *> *words = [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    BOOL searching = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length > 0;
    BOOL anything = NO;
    for (NSArray *section in self.sections) {
        BOOL any = NO;
        for (NSView *row in section[2]) {
            BOOL visible = (row != self.squareRow || DPOn[DPEdgeToEdge]) && [self matches:row words:words];
            NSArray<NSView *> *arranged = ((NSStackView *)row.superview).arrangedSubviews;
            NSUInteger index = [arranged indexOfObject:row];
            row.hidden = !visible;
            if (index > 0) arranged[index - 1].hidden = !visible || !any;
            any |= visible;
        }
        for (NSView *view in @[section[0], section[1]]) view.hidden = !any;
        anything |= any;
    }
    self.noResults.hidden = anything;
    self.notice.hidden = searching;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateRows];
}

- (void)toggle:(NSSwitch *)sender {
    DPSetTweak(sender.tag, sender.state == NSControlStateValueOn);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.allowsImplicitAnimation = YES;
        [self updateRows];
        [self layoutSubtreeIfNeeded];
    }];
}

- (void)showStatus:(NSDictionary *)status {
    NSString *running = [NSString stringWithFormat:@"Dia %@ (%@)",
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    id staged = status[@"staged"];
    BOOL ready = [staged isKindOfClass:NSString.class];
    self.status.stringValue = !status ? [running stringByAppendingString:@" · couldn’t check for updates"]
                            : ready   ? [NSString stringWithFormat:@"Dia %@ installs when you quit", staged]
                                      : [running stringByAppendingString:@" · up to date"];
    self.relaunchButton.hidden = !ready;
    self.checkButton.enabled = YES;
}

- (void)checkForUpdates:(NSButton *)sender {
    sender.enabled = NO;
    self.status.stringValue = @"Checking for updates…";
    __weak DPPaneView *weakSelf = self;
    DPCheckForUpdates(^(NSDictionary *status) { [weakSelf showStatus:status]; });
}

- (void)refresh {
    __weak DPPaneView *weakSelf = self;
    DPRunCLI(@[@"status", @"--json"], ^(NSString *output) {
        id status = output ? [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
        [weakSelf showStatus:[status isKindOfClass:NSDictionary.class] ? status : nil];
    });
}

- (void)relaunchToUpdate:(id)sender {
    DPHandOffAndQuit(@"apply");
}

- (void)restore:(id)sender {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Restore the original Dia?";
    alert.informativeText = @"Dia will relaunch without patches, and its own updater takes over again. Run the installer to patch it again later.";
    [alert addButtonWithTitle:@"Restore and Relaunch"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPHandOffAndQuit(@"uninstall");
    }];
}
@end

@interface DPSidebarRow : NSControl
@property (nonatomic) BOOL selected;
@property (nonatomic, strong) NSImageView *icon;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic) NSRect iconFrame, labelFrame, pillFrame;
@property (nonatomic, strong) NSFont *labelFont;
@property (nonatomic) CGFloat pillRadius;
@end

@implementation DPSidebarRow {
    NSVisualEffectView *_selection;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _selection = [NSVisualEffectView new];
    _selection.material = NSVisualEffectMaterialSelection;
    _selection.state = NSVisualEffectStateFollowsWindowActiveState;
    _selection.wantsLayer = YES;
    _selection.hidden = YES;
    _icon = [DPSolidImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"wand.and.stars" accessibilityDescription:nil]];
    _label = [DPSolidLabel labelWithString:@"Patches"];
    for (NSView *v in @[_selection, _icon, _label]) [self addSubview:v];
    self.accessibilityRole = NSAccessibilityButtonRole;
    self.accessibilityLabel = @"Patches";
    return self;
}

- (BOOL)allowsVibrancy { return NO; }
- (BOOL)isFlipped { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSNotificationName name in @[NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification]) {
        [center removeObserver:self name:name object:nil];
        if (self.window) [center addObserver:self selector:@selector(redraw) name:name object:self.window];
    }
}

- (void)redraw { self.needsDisplay = YES; }

// Dia's sidebar labels get their dark ink from vibrancy, which this row can't get outside Dia's table, so it draws solid text in the plain appearance.
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.label.appearance = [NSAppearance appearanceNamed:[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]]];
}

- (void)layout {
    [super layout];
    _selection.frame = self.pillFrame;
    _selection.layer.cornerRadius = self.pillRadius;
    _selection.layer.masksToBounds = YES;
    self.icon.frame = self.iconFrame;
    [self.label sizeToFit];
    NSRect labelFrame = self.labelFrame;
    labelFrame.size.width = MAX(labelFrame.size.width, NSWidth(self.label.frame));
    self.label.frame = labelFrame;
}

- (void)setSelected:(BOOL)selected { _selected = selected; [self redraw]; }

- (void)updateLayer {
    BOOL key = self.window.isKeyWindow, emphasized = self.selected && key;
    _selection.hidden = !self.selected;
    _selection.emphasized = emphasized;
    self.label.textColor = emphasized ? NSColor.alternateSelectedControlTextColor : NSColor.textColor;
    NSFont *font = self.labelFont ?: self.label.font;
    NSFont *face = self.selected ? [NSFont systemFontOfSize:font.pointSize weight:NSFontWeightSemibold] : font;
    if (![self.label.font isEqual:face]) {
        self.label.font = face;
        self.needsLayout = YES;
    }
    self.icon.contentTintColor = emphasized ? NSColor.alternateSelectedControlTextColor : key ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor;
}
@end

static NSString *const DPSettingsControllerClass = @"_TtC11Preferences38SidebarPreferencesWindowViewController";

@interface DPSettings : NSObject
@property (nonatomic, weak) NSWindow *window;
@property (nonatomic, weak) NSView *sidebar, *detail;
@property (nonatomic, weak) NSTableView *table;
@property (nonatomic, weak) NSTextField *title;
@property (nonatomic) NSInteger deselectedIndex;
@property (nonatomic, copy) NSString *originalTitle;
@property (nonatomic, strong) DPSidebarRow *row;
@property (nonatomic, strong) DPPaneView *pane;
@property (nonatomic, strong) id monitor;
@end

@implementation DPSettings

+ (void)attachTo:(NSWindow *)window {
    static NSMapTable<NSWindow *, DPSettings *> *attached;
    attached = attached ?: [NSMapTable weakToStrongObjectsMapTable];
    DPSettings *settings = [attached objectForKey:window];
    if (settings) return [settings reposition];
    settings = [DPSettings new];
    if ([settings attachTo:window]) [attached setObject:settings forKey:window];
}

- (BOOL)attachTo:(NSWindow *)window {
    NSSplitViewController *split = (NSSplitViewController *)window.contentViewController;
    if (split.splitViewItems.count < 2) return NO;
    NSView *sidebar = split.splitViewItems.firstObject.viewController.view;
    NSTableView *table = (NSTableView *)DPFindView(sidebar, ^BOOL(NSView *v) { return [v isKindOfClass:NSTableView.class]; });
    if (table.numberOfRows == 0) return NO;

    self.window = window;
    self.sidebar = sidebar;
    self.detail = split.splitViewItems.lastObject.viewController.view;
    self.table = table;
    self.row = [DPSidebarRow new];
    [sidebar addSubview:self.row];
    [self reposition];
    for (NSView *v in @[table, sidebar]) {
        v.postsFrameChangedNotifications = YES;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reposition) name:NSViewFrameDidChangeNotification object:v];
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(diaSelectionChanged) name:NSTableViewSelectionDidChangeNotification object:table];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keepDiaRowDeselected) name:NSWindowDidBecomeKeyNotification object:window];

    // Dia's sidebar handles clicks above the table view, so the row's clicks are consumed before it selects a row.
    __weak DPSettings *weakSelf = self;
    NSEventMask mask = NSEventMaskLeftMouseDown | NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp;
    self.monitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
        DPSettings *me = weakSelf;
        if (!me || event.window != me.window) return event;
        NSView *hit = [me.window.contentView.superview hitTest:event.locationInWindow];
        if ([hit isDescendantOf:me.row]) {
            if (event.type == NSEventTypeLeftMouseDown) {
                [NSApp activate];
                [me.window makeKeyAndOrderFront:nil];
                [me showPane];
            }
            return nil;
        }
        if (!me.pane.superview || [hit isDescendantOf:me.pane]) return event;
        if ([hit isDescendantOf:me.detail]) return nil;
        BOOL onDiaRow = [me.table rowAtPoint:[me.table convertPoint:event.locationInWindow fromView:nil]] >= 0;
        if (event.type == NSEventTypeLeftMouseDown && onDiaRow) [me hidePane];
        return event;
    }];
    return YES;
}

- (void)dealloc {
    [NSEvent removeMonitor:_monitor];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)reposition {
    NSTableView *table = self.table;
    NSInteger count = table.numberOfRows;
    if (count < 2 || !self.sidebar) return;
    NSRect last = [self.sidebar convertRect:[table rectOfRow:count - 1] fromView:table];
    NSRect previous = [self.sidebar convertRect:[table rectOfRow:count - 2] fromView:table];
    self.row.frame = NSOffsetRect(last, 0, NSMinY(last) - NSMinY(previous));

    NSTableRowView *rowView = [table rowViewAtRow:count - 1 makeIfNecessary:NO];
    NSTableCellView *cell = [table viewAtColumn:0 row:count - 1 makeIfNecessary:NO];
    if (!rowView || !cell) return;
    NSRect (^inRow)(NSView *) = ^NSRect(NSView *v) {
        NSRect r = [rowView convertRect:v.bounds fromView:v];
        if (!rowView.isFlipped) r.origin.y = NSHeight(rowView.bounds) - NSMaxY(r);
        return r;
    };
    self.row.iconFrame = inRow(cell.imageView);
    self.row.labelFrame = inRow(cell.textField);
    NSInteger plain = table.selectedRow == count - 1 ? 0 : count - 1;
    self.row.labelFont = [[table viewAtColumn:0 row:plain makeIfNecessary:NO] textField].font ?: self.row.labelFont;
    self.row.icon.symbolConfiguration = cell.imageView.image.symbolConfiguration;

    NSTableRowView *selected = table.selectedRow >= 0 ? [table rowViewAtRow:table.selectedRow makeIfNecessary:NO] : nil;
    NSVisualEffectView *pill = (NSVisualEffectView *)DPFindView(selected, ^BOOL(NSView *v) { return [v isKindOfClass:NSVisualEffectView.class]; });
    if (selected && pill.superview == selected) {
        NSRect r = pill.frame;
        if (!selected.isFlipped) r.origin.y = NSHeight(selected.bounds) - NSMaxY(r);
        self.row.pillFrame = r;
        self.row.pillRadius = pill.maskImage.capInsets.top ?: pill.layer.cornerRadius;
    } else if (NSIsEmptyRect(self.row.pillFrame)) {
        self.row.pillFrame = NSInsetRect(rowView.bounds, 10, 0);
    }
    if (self.row.pillRadius <= 0) self.row.pillRadius = 6;
    self.row.needsLayout = YES;
}

- (void)showPane {
    if (self.pane.superview || !self.detail) return;
    self.pane = self.pane ?: [[DPPaneView alloc] initWithFrame:self.detail.bounds];
    self.pane.frame = self.detail.bounds;
    self.pane.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.detail addSubview:self.pane positioned:NSWindowAbove relativeTo:nil];
    [self.pane refresh];
    NSToolbar *toolbar = self.window.toolbar;
    if (toolbar && ![toolbar.items containsObject:self.pane.searchItem]) {
        objc_setAssociatedObject(toolbar, &DPSearchItemKey, self.pane.searchItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [toolbar insertItemWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier atIndex:toolbar.items.count];
        [toolbar insertItemWithItemIdentifier:DPSearchItemIdentifier atIndex:toolbar.items.count];
    }

    NSInteger selected = self.table.selectedRow;
    if (selected < 0) return;
    NSString *name = [[self.table viewAtColumn:0 row:selected makeIfNecessary:NO] textField].stringValue;
    NSView *content = self.window.contentView;
    self.title = (NSTextField *)DPFindView(content.superview, ^BOOL(NSView *v) {
        return [v isKindOfClass:NSTextField.class] && !v.hiddenOrHasHiddenAncestor && ![v isDescendantOf:content]
            && [((NSTextField *)v).stringValue isEqualToString:name];
    });
    self.originalTitle = self.title.stringValue;
    self.title.stringValue = @"Patches";
    self.deselectedIndex = selected;
    [self.table rowViewAtRow:selected makeIfNecessary:NO].selected = NO;
    self.row.selected = YES;
}

- (void)keepDiaRowDeselected {
    if (!self.pane.superview) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.pane.superview) return;
        [self.detail addSubview:self.pane positioned:NSWindowAbove relativeTo:nil];
        [self.table rowViewAtRow:self.deselectedIndex makeIfNecessary:NO].selected = NO;
        self.row.selected = YES;
    });
}

- (void)diaSelectionChanged {
    NSInteger selected = self.table.selectedRow;
    if (self.pane.superview && selected >= 0 && selected != self.deselectedIndex) [self hidePane];
    else [self keepDiaRowDeselected];
}

- (void)hidePane {
    [self.pane removeFromSuperview];
    NSToolbar *toolbar = self.window.toolbar;
    NSUInteger index = [toolbar.items indexOfObject:self.pane.searchItem];
    if (index != NSNotFound) {
        [toolbar removeItemAtIndex:index];
        if (index > 0 && [toolbar.items[index - 1].itemIdentifier isEqualToString:NSToolbarFlexibleSpaceItemIdentifier]) [toolbar removeItemAtIndex:index - 1];
    }
    self.pane.searchItem.searchField.stringValue = @"";
    [self.pane updateRows];
    if ([self.title.stringValue isEqualToString:@"Patches"]) self.title.stringValue = self.originalTitle;
    if (self.table.selectedRow == self.deselectedIndex) [self.table rowViewAtRow:self.deselectedIndex makeIfNecessary:NO].selected = YES;
    self.row.selected = NO;
}
@end

static NSToolbarItem *DPSettings_toolbarItem(id self, SEL _cmd, NSToolbar *toolbar, NSToolbarItemIdentifier identifier, BOOL willInsert) {
    if ([identifier isEqualToString:DPSearchItemIdentifier]) return objc_getAssociatedObject(toolbar, &DPSearchItemKey);
    return DPCallOriginal(NSToolbarItem *(*)(id, SEL, NSToolbar *, NSToolbarItemIdentifier, BOOL), self, _cmd, toolbar, identifier, willInsert);
}

static void DPSettings_viewDidAppear(NSViewController *self, SEL _cmd) {
    DPCallOriginal(void (*)(id, SEL), self, _cmd);
    NSWindow *window = self.view.window;
    dispatch_async(dispatch_get_main_queue(), ^{ if (window) [DPSettings attachTo:window]; });
}

#pragma mark - Bootstrap

__attribute__((constructor)) static void DPInit(void) {
    DPDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    for (int i = 0; i < DPTweakCount; i++) {
        id value = [DPDefaults objectForKey:DPKeys[i]];
        DPOn[i] = value ? [value boolValue] : DPDefaultsOn[i];
    }
    for (int i = 0; i < DPAnimatedCount; i++) DPProgress[i] = DPOn[i];
    DPContainers = [NSHashTable weakObjectsHashTable];
    DPPanes = [NSHashTable weakObjectsHashTable];
    DPBars = [NSHashTable weakObjectsHashTable];
    DPSuppressed = [NSHashTable weakObjectsHashTable];

    DPHook(DPContainerClass(), @selector(setFrame:), (IMP)DPContainer_setFrame);
    for (NSString *selector in @[@"layout", @"updateLayer"])
        DPHook(DPContainerClass(), NSSelectorFromString(selector), (IMP)DPContainer_layoutOrUpdateLayer);
    DPHook(NSClassFromString(@"_TtC5ARCUI10ShadowView"), @selector(layout), (IMP)DPShadow_layout);
    DPHook(NSClassFromString(@"_TtC11ContentPane15ContentPaneView"), @selector(layout), (IMP)DPPane_layout);
    DPHook(NSClassFromString(@"_TtC11ContentPane15ContentPaneView"), @selector(hitTest:), (IMP)DPPane_hitTest);
    for (NSString *bar in @[@"_TtC13NavigationBar17NavigationBarView", @"_TtC10TabSidebar17SidebarHeaderView", @"_TtC10TabSidebar26SidebarContainerFooterView"])
        DPHook(NSClassFromString(bar), @selector(layout), (IMP)DPBar_layout);
    DPHook(NSClassFromString(@"_TtC10TabSidebar30SidebarContainerViewController"), @selector(viewDidLayout), (IMP)DPSidebar_viewDidLayout);
    DPHook(NSClassFromString(@"_TtC8TabStrip31TabStripContainerViewController"), @selector(viewWillLayout), (IMP)DPTabStrip_viewWillLayout);
    DPHook(DPToolbarClass(), @selector(hitTest:), (IMP)DPToolbar_hitTest);
    DPHook(NSClassFromString(@"_TtC13OpenURLClient19OpenURLEventManager"), @selector(handleEvent:withReplyEvent:), (IMP)DPOpenURLEvent_handle);
    DPHook(object_getClass(NSScroller.class), @selector(preferredScrollerStyle), (IMP)DPScroller_preferredScrollerStyle);
    DPHook(NSClassFromString(DPSettingsControllerClass), @selector(viewDidAppear), (IMP)DPSettings_viewDidAppear);
    DPHook(NSClassFromString(DPSettingsControllerClass), @selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:), (IMP)DPSettings_toolbarItem);

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *_) {
        DPInstallUpdateMenuItem();
        DPUpdateRevealPolling();
        DPInstallLittleDia();
        // Swift's readable class names only resolve once its runtime is up, so this one is looked up by its mangled name, late.
        DPHook(NSClassFromString(@"_TtC3ADK18WebContentChromium"), NSSelectorFromString(@"webContents:decidePolicyForNavigationAction:"),
               (IMP)DPWebContent_decidePolicy);
        DPRunCLI(@[@"update"], nil);
    }];
    [center addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *_) {
        DPCloseLittleWindows();
        DPApplyStagedOnQuit();
    }];
}
