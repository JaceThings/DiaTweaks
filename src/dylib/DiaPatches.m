#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <os/log.h>
#import <objc/message.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, DPTweak) {
    DPEdgeToEdge, DPHideToolbar, DPSquareSidebarCorners, DPAnimatedCount,
    DPHideChatButton = DPAnimatedCount, DPHideSidebarButton, DPTweakCount
};

static NSString *const DPKeys[DPTweakCount] = {@"edgeToEdge", @"hideToolbar", @"squareSidebarCorners", @"hideChatButton", @"hideSidebarButton"};
static const BOOL DPDefaultsOn[DPTweakCount] = {YES, NO, YES, NO, NO};
static const CGFloat DPWindowPadding = 6;
static const CFTimeInterval DPAnimationDuration = 0.25;

static BOOL DPOn[DPTweakCount];
static CGFloat DPProgress[DPAnimatedCount];
static NSUserDefaults *DPDefaults;
static NSHashTable<NSView *> *DPContainers, *DPPanes, *DPBars, *DPSuppressed;
static NSHashTable *DPTrackedContents, *DPBrowsers;
static NSMapTable *DPBrowserByContents, *DPDelegateByBrowser, *DPWindowByBrowser;
static char DPRequestedFrameKey, DPAssignedFrameKey, DPButtonKey, DPBaseRadiusKey, DPAssignedRadiusKey, DPFillsKey, DPChatKey, DPOriginalPathKey, DPAssignedPathKey;
static char DPSessionKey;

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

#pragma mark - Logging

// defaults write com.diapatches debugLogging -bool true
static NSMutableArray<NSString *> *DPHookNotes;

static os_log_t DPGroupLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.diapatches", "grouping"); });
    return log;
}

static void DPLog(NSString *message) {
    if (![DPDefaults boolForKey:@"debugLogging"]) return;
    os_log(DPGroupLog(), "%{public}@", message);
}

static void DPNoteHook(Class cls, SEL sel, NSString *status) {
    NSString *line = [NSString stringWithFormat:@"hook %s %s: %@",
        cls ? class_getName(cls) : "(nil)", sel ? sel_getName(sel) : "(nil)", status];
    if (!DPHookNotes) DPHookNotes = [NSMutableArray array];
    [DPHookNotes addObject:line];
    DPLog(line);
}

#pragma mark - Hooks

typedef struct { Class cls; SEL sel; IMP imp; } DPOriginal;
static DPOriginal DPOriginals[24];
static int DPOriginalCount;

static void DPHook(Class cls, SEL sel, IMP replacement) {
    Method method = cls ? class_getInstanceMethod(cls, sel) : NULL;
    if (!cls || !method) {
        DPNoteHook(cls, sel, cls ? @"selector missing" : @"class missing");
        return;
    }
    if (method_getImplementation(method) == replacement) {
        DPNoteHook(cls, sel, @"already hooked");
        return;
    }
    if (DPOriginalCount == 24) {
        DPNoteHook(cls, sel, @"hook table full");
        return;
    }
    IMP original = method_getImplementation(method);
    if (!class_addMethod(cls, sel, replacement, method_getTypeEncoding(method))) method_setImplementation(method, replacement);
    DPOriginals[DPOriginalCount++] = (DPOriginal){cls, sel, original};
    DPNoteHook(cls, sel, @"installed");
}

static IMP DPOriginalIMP(id object, SEL sel) {
    for (Class c = object_getClass(object); c; c = class_getSuperclass(c))
        for (int i = 0; i < DPOriginalCount; i++)
            if (DPOriginals[i].cls == c && DPOriginals[i].sel == sel) return DPOriginals[i].imp;
    abort();
}

#define DPCallOriginal(type, object, sel, ...) ((type)DPOriginalIMP(object, sel))(object, sel, ##__VA_ARGS__)

#pragma mark - Toolbar buttons

static NSInteger DPButtonTweak(NSView *view) {
    NSNumber *tweak = objc_getAssociatedObject(view, &DPButtonKey);
    if (tweak) return tweak.integerValue;
    NSString *label = view.accessibilityLabel;
    NSInteger match = [label isEqualToString:@"Chat with this tab"] ? DPHideChatButton
                    : [label isEqualToString:@"Toggle sidebar"]     ? DPHideSidebarButton
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
    for (NSView *bar in DPBars) {
        bar.needsLayout = YES;
        [bar layoutSubtreeIfNeeded];
    }
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

// The bar stays in Dia's layout: hiding it makes Dia reflow in ways it won't undo.
static NSView *DPToolbar_hitTest(NSView *self, SEL _cmd, NSPoint point) {
    return DPOn[DPHideToolbar] ? nil : DPCallOriginal(NSView *(*)(id, SEL, NSPoint), self, _cmd, point);
}

static void DPApplyToolbar(NSView *pane) {
    NSView *bar = nil;
    for (NSView *sub in pane.subviews) if ([sub isKindOfClass:DPToolbarClass()]) { bar = sub; break; }
    if (!bar) return;

    CGFloat progress = DPProgress[DPHideToolbar];
    bar.alphaValue = 1 - progress;
    NSView *lowest = pane.subviews.firstObject;
    if (progress > 0 && lowest != bar) [pane addSubview:bar positioned:NSWindowBelow relativeTo:lowest];
    else if (progress == 0 && lowest == bar) [pane addSubview:bar positioned:NSWindowAbove relativeTo:nil];

    BOOL flipped = pane.isFlipped;
    CGFloat (^top)(NSRect) = ^CGFloat(NSRect r) { return flipped ? NSMinY(r) : NSHeight(pane.bounds) - NSMaxY(r); };
    CGFloat (^bottom)(NSRect) = ^CGFloat(NSRect r) { return flipped ? NSMaxY(r) : NSHeight(pane.bounds) - NSMinY(r); };
    CGFloat shift = NSHeight(bar.frame) * progress, edge = bottom(bar.frame);
    NSMutableArray<NSView *> *stack = [NSMutableArray new];
    for (NSView *sub in pane.subviews) if (sub != bar) [stack addObject:sub];
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

#pragma mark - Group tabs by domain

// One-shot command. The registry only remembers live browsers and web contents so the menu
// action can read ArcSessionID.identifier. Nothing is grouped until the menu item is chosen.
static const NSInteger DPGroupMenuTag = 0xD1A7001;
static NSString *const DPGroupMenuTitle = @"Group Tabs by Domain";
static BOOL DPInserting;

static long long DPLongID(id value) {
    if (!value || value == NSNull.null) return 0;
    if ([value isKindOfClass:NSNumber.class]) return ((NSNumber *)value).longLongValue;
    if ([value isKindOfClass:NSString.class]) {
        NSScanner *scanner = [NSScanner scannerWithString:value];
        long long number = 0;
        return [scanner scanLongLong:&number] && [scanner isAtEnd] ? number : 0;
    }
    if ([value respondsToSelector:@selector(identifier)]) {
        NSInteger (*msg)(id, SEL) = (void *)objc_msgSend;
        return msg(value, @selector(identifier));
    }
    return 0;
}

static id DPMsg(id object, SEL sel) {
    id (*msg)(id, SEL) = (void *)objc_msgSend;
    return object ? msg(object, sel) : nil;
}

static BOOL DPMsgBool(id object, SEL sel) {
    BOOL (*msg)(id, SEL) = (void *)objc_msgSend;
    return object ? msg(object, sel) : NO;
}

static NSString *DPText(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSURL.class]) return ((NSURL *)value).absoluteString;
    if ([value isKindOfClass:NSNumber.class]) return ((NSNumber *)value).stringValue;
    return nil;
}

static long long DPContentsSession(id contents) {
    return [contents respondsToSelector:@selector(sessionId)] ? DPLongID(DPMsg(contents, @selector(sessionId))) : 0;
}

static NSString *DPDecodeLabel(NSString *label) {
    if (![label hasPrefix:@"xn--"]) return label;
    NSString *decoded = [label stringByApplyingTransform:@"Any-Punycode" reverse:YES];
    return decoded.length && ![decoded isEqualToString:label] ? decoded.lowercaseString : label;
}

// nil for the new tab page, dia://, chrome://, file and other internal pages.
static NSString *DPDomainKey(NSString *urlString) {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return nil;
    NSString *host = url.host.lowercaseString;
    if (!host.length) return nil;
    while ([host hasSuffix:@"."]) host = [host substringToIndex:host.length - 1];
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    for (NSString *part in [host componentsSeparatedByString:@"."]) [labels addObject:DPDecodeLabel(part)];
    host = [labels componentsJoinedByString:@"."];
    if ([host hasPrefix:@"www."] && host.length > 4) host = [host substringFromIndex:4];
    return host.length ? host : nil;
}

static void DPRemember(id contents, id session, id browser, id delegate) {
    if (browser) [DPBrowsers addObject:browser];
    if (browser && delegate) [DPDelegateByBrowser setObject:delegate forKey:browser];
    if (!contents || !browser) return;
    [DPBrowserByContents setObject:browser forKey:contents];
    [DPTrackedContents addObject:contents];
    long long sid = DPLongID(session);
    if (sid <= 0) sid = DPContentsSession(contents);
    if (sid > 0) objc_setAssociatedObject(contents, &DPSessionKey, @(sid), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id DPGroupingDelegate(id self, id browser) {
    if ([self respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]) return self;
    return [DPDelegateByBrowser objectForKey:browser];
}

static void DPBrowser_setDelegate(id self, SEL _cmd, id delegate) {
    DPCallOriginal(void (*)(id, SEL, id), self, _cmd, delegate);
    [DPBrowsers addObject:self];
    if (delegate) [DPDelegateByBrowser setObject:delegate forKey:self];
    DPLog([NSString stringWithFormat:@"setDelegate browser=%p delegate=%@ responds=%d",
        (void *)self, delegate ? NSStringFromClass([delegate class]) : @"nil",
        [delegate respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]]);
}

static void DPBrowser_setWindow(id self, SEL _cmd, NSWindow *window) {
    DPCallOriginal(void (*)(id, SEL, NSWindow *), self, _cmd, window);
    [DPBrowsers addObject:self];
    if (window) [DPWindowByBrowser setObject:window forKey:self];
    DPLog([NSString stringWithFormat:@"setWindow browser=%p window=%@", (void *)self, window.title ?: @"(untitled)"]);
}

static void DPBrowser_didRestore(id self, SEL _cmd, id browser, id contents, id session) {
    DPCallOriginal(void (*)(id, SEL, id, id, id), self, _cmd, browser, contents, session);
    DPLog([NSString stringWithFormat:@"didRestore contents=%@ identifier=%lld",
        contents ? NSStringFromClass([contents class]) : @"nil", DPLongID(session)]);
    if (browser) DPRemember(contents, session, browser, DPGroupingDelegate(self, browser));
}

static void DPBrowser_didCreate(id self, SEL _cmd, id browser, id contents, BOOL active) {
    DPCallOriginal(void (*)(id, SEL, id, id, BOOL), self, _cmd, browser, contents, active);
    DPLog([NSString stringWithFormat:@"didCreate contents=%@ active=%d session=%lld url=%@",
        contents ? NSStringFromClass([contents class]) : @"nil", active, DPContentsSession(contents),
        DPText(DPMsg(contents, @selector(url))) ?: @""]);
    if (browser && contents) DPRemember(contents, nil, browser, DPGroupingDelegate(self, browser));
}

static BOOL DPIsNewGroupTitle(NSString *title) {
    if ([title isEqualToString:@"New Group with Tab"] || [title isEqualToString:@"New Group with Tabs"]) return YES;
    return [title hasPrefix:@"New Group with "] && ([title hasSuffix:@" Tab"] || [title hasSuffix:@" Tabs"]);
}

@interface DPGroupCommand : NSObject
+ (instancetype)shared;
- (void)groupTabsByDomain:(id)sender;
@end

static id DPCommandBrowser(void) {
    NSWindow *key = NSApp.keyWindow;
    id only = nil;
    NSUInteger ready = 0;
    for (id browser in DPBrowsers.allObjects) {
        if (![[DPDelegateByBrowser objectForKey:browser] respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]) continue;
        ready++;
        only = browser;
        NSWindow *window = [DPWindowByBrowser objectForKey:browser];
        if (window && key && window == key) return browser;
    }
    if (ready == 1) return only;
    DPLog([NSString stringWithFormat:@"command: %lu browsers, key window not matched (%@)",
        (unsigned long)ready, key.title ?: @"none"]);
    return nil;
}

static void DPCollectPinned(NSMutableSet<NSNumber *> *sessions, NSMutableSet<NSString *> *pinnedURLs, NSMutableSet<NSString *> *openURLs) {
    id app = NSApp.delegate;
    if (![app respondsToSelector:@selector(appleScriptWindows)]) return;
    NSArray *windows = DPMsg(app, @selector(appleScriptWindows));
    if (![windows isKindOfClass:NSArray.class]) return;
    for (id window in windows) {
        if (![window respondsToSelector:@selector(appleScriptTabs)]) continue;
        NSArray *tabs = DPMsg(window, @selector(appleScriptTabs));
        if (![tabs isKindOfClass:NSArray.class]) continue;
        for (id tab in tabs) {
            NSString *url = [tab respondsToSelector:@selector(URL)] ? DPText(DPMsg(tab, @selector(URL))) : nil;
            BOOL pinned = [tab respondsToSelector:@selector(isPinned)] && DPMsgBool(tab, @selector(isPinned));
            id rawID = [tab respondsToSelector:@selector(tabId)] ? DPMsg(tab, @selector(tabId)) : nil;
            DPLog([NSString stringWithFormat:@"script tab id=%@ class=%@ pinned=%d url=%@",
                rawID ?: @"", rawID ? NSStringFromClass([rawID class]) : @"", pinned, url ?: @""]);
            if (pinned && url.length) [pinnedURLs addObject:url];
            else if (url.length) [openURLs addObject:url];
            if (!pinned) continue;
            long long sid = DPLongID(rawID);
            if (sid > 0) [sessions addObject:@(sid)];
        }
    }
}

static BOOL DPPinned(long long sid, NSString *url, NSSet<NSNumber *> *sessions, NSSet<NSString *> *urls, NSSet<NSString *> *openURLs) {
    if ([sessions containsObject:@(sid)]) return YES;
    return url.length && [urls containsObject:url] && ![openURLs containsObject:url];
}

static id DPGroupProperties(NSString *title) {
    Class cls = NSClassFromString(@"ArcTabGroupProperties");
    id props = cls ? [cls new] : nil;
    if ([props respondsToSelector:@selector(setTitle:)]) [props setTitle:title];
    return props;
}

static void DPRunOps(id delegate, id browser, NSArray<NSDictionary *> *ops, NSUInteger index) {
    if (index >= ops.count) { DPLog(@"command finished"); return; }
    NSDictionary *op = ops[index];
    DPLog([NSString stringWithFormat:@"op %@ title=%@ group=%@ ids=%@", op[@"op"], op[@"title"] ?: @"", op[@"group"] ?: @"", op[@"ids"]]);
    void (^next)(id) = ^(id result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL ok = [result respondsToSelector:@selector(success)] && DPMsgBool(result, @selector(success));
            NSString *groupID = [result respondsToSelector:@selector(groupId)] ? DPText(DPMsg(result, @selector(groupId))) : nil;
            NSString *error = [result respondsToSelector:@selector(error)] ? DPText(DPMsg(result, @selector(error))) : nil;
            DPLog([NSString stringWithFormat:@"completion %@ ok=%d groupId=%@ error=%@", op[@"op"], ok, groupID ?: @"", error ?: @""]);
            DPRunOps(delegate, browser, ops, index + 1);
        });
    };
    void (*create)(id, SEL, id, NSArray *, id, void (^)(id)) = (void *)objc_msgSend;
    void (*add)(id, SEL, id, NSString *, NSArray *, void (^)(id)) = (void *)objc_msgSend;
    if ([op[@"op"] isEqual:@"create"]) {
        id props = DPGroupProperties(op[@"title"]);
        if (!props) { DPLog(@"create skipped: ArcTabGroupProperties missing"); DPRunOps(delegate, browser, ops, index + 1); return; }
        create(delegate, @selector(browser:createTabGroupWithSessionIds:properties:completion:), browser, op[@"ids"], props, next);
    } else {
        add(delegate, @selector(browser:addTabsToGroupWithId:sessionIds:completion:), browser, op[@"group"], op[@"ids"], next);
    }
}

// Loose tabs join an existing group whose title is exactly the domain. Tabs in any other group stay put.
static NSArray<NSDictionary *> *DPOps(NSArray<NSDictionary *> *tabs, NSArray *groups) {
    NSMutableDictionary<NSNumber *, NSString *> *groupTitle = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *homeID = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSMutableSet<NSNumber *> *> *homeMembers = [NSMutableDictionary dictionary];
    for (id info in groups) {
        if (![info respondsToSelector:@selector(groupId)]) continue;
        NSString *groupID = DPText(DPMsg(info, @selector(groupId)));
        NSString *title = [info respondsToSelector:@selector(title)] ? DPText(DPMsg(info, @selector(title))) ?: @"" : @"";
        if (!groupID.length) continue;
        NSArray *rawIDs = [info respondsToSelector:@selector(tabSessionIds)] ? DPMsg(info, @selector(tabSessionIds)) : nil;
        if ([rawIDs isKindOfClass:NSArray.class]) for (id raw in rawIDs) {
            long long sid = DPLongID(raw);
            if (sid > 0) groupTitle[@(sid)] = title;
        }
        if (title.length && !homeID[title]) {
            homeID[title] = groupID;
            homeMembers[title] = [NSMutableSet set];
        }
        if (homeMembers[title]) {
            if ([rawIDs isKindOfClass:NSArray.class]) for (id raw in rawIDs) {
                long long sid = DPLongID(raw);
                if (sid > 0) [homeMembers[title] addObject:@(sid)];
            }
        }
    }
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *pools = [NSMutableDictionary dictionary];
    for (NSDictionary *tab in tabs) {
        NSNumber *sid = tab[@"session"];
        NSString *domain = tab[@"domain"];
        NSString *title = groupTitle[sid];
        if (title && ![title isEqualToString:domain]) {
            DPLog([NSString stringWithFormat:@"leave sid=%@ in group \"%@\"", sid, title]);
            continue;
        }
        NSMutableArray *pool = pools[domain] ?: (pools[domain] = [NSMutableArray array]);
        [pool addObject:tab];
    }
    NSMutableArray<NSDictionary *> *ops = [NSMutableArray array];
    for (NSString *domain in pools) {
        NSArray<NSDictionary *> *pool = pools[domain];
        if (pool.count < 2) {
            DPLog([NSString stringWithFormat:@"skip %@ (%lu tab%@)", domain, (unsigned long)pool.count, pool.count == 1 ? @"" : @"s"]);
            continue;
        }
        NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
        for (NSDictionary *tab in pool) if (![homeMembers[domain] containsObject:tab[@"session"]]) [ids addObject:tab[@"session"]];
        if (!ids.count) continue;
        if (homeID[domain]) [ops addObject:@{@"op": @"add", @"group": homeID[domain], @"ids": ids}];
        else if (ids.count >= 2) [ops addObject:@{@"op": @"create", @"title": domain, @"ids": ids}];
    }
    return ops;
}

static void DPGroupTabsOnce(void) {
    for (NSString *line in DPHookNotes) DPLog(line);
    id browser = DPCommandBrowser();
    if (!browser) return;
    id delegate = [DPDelegateByBrowser objectForKey:browser];
    if (![delegate respondsToSelector:@selector(browser:getAllTabGroupsWithCompletion:)]) {
        DPLog(@"command: grouping delegate missing");
        return;
    }
    NSMutableSet<NSNumber *> *pinnedSessions = [NSMutableSet set];
    NSMutableSet<NSString *> *pinnedURLs = [NSMutableSet set], *openURLs = [NSMutableSet set];
    DPCollectPinned(pinnedSessions, pinnedURLs, openURLs);
    NSMutableArray<NSDictionary *> *tabs = [NSMutableArray array];
    for (id contents in DPTrackedContents.allObjects) {
        if ([DPBrowserByContents objectForKey:contents] != browser) continue;
        long long sid = DPContentsSession(contents);
        if (sid <= 0) sid = DPLongID(objc_getAssociatedObject(contents, &DPSessionKey));
        NSString *url = DPText(DPMsg(contents, @selector(url)));
        NSString *domain = DPDomainKey(url);
        if (sid <= 0 || !domain) {
            DPLog([NSString stringWithFormat:@"skip contents=%p sid=%lld domain=%@ url=%@", (void *)contents, sid, domain ?: @"", url ?: @""]);
            continue;
        }
        if (DPPinned(sid, url, pinnedSessions, pinnedURLs, openURLs)) {
            DPLog([NSString stringWithFormat:@"skip pinned sid=%lld url=%@", sid, url ?: @""]);
            continue;
        }
        DPLog([NSString stringWithFormat:@"tab sid=%lld domain=%@ url=%@", sid, domain, url ?: @""]);
        [tabs addObject:@{@"session": @(sid), @"domain": domain}];
    }
    DPLog([NSString stringWithFormat:@"command browser=%p tabs=%lu", (void *)browser, (unsigned long)tabs.count]);
    void (*ask)(id, SEL, id, void (^)(NSArray *)) = (void *)objc_msgSend;
    NSArray *snapshot = [tabs copy];
    ask(delegate, @selector(browser:getAllTabGroupsWithCompletion:), browser, ^(NSArray *groups) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![groups isKindOfClass:NSArray.class]) { DPLog(@"groups callback was not an array"); return; }
            for (id info in groups)
                DPLog([NSString stringWithFormat:@"existing group id=%@ title=%@ sessions=%@",
                    DPText(DPMsg(info, @selector(groupId))) ?: @"", DPText(DPMsg(info, @selector(title))) ?: @"",
                    [info respondsToSelector:@selector(tabSessionIds)] ? DPMsg(info, @selector(tabSessionIds)) : @""]);
            NSArray *ops = DPOps(snapshot, groups);
            if (!ops.count) DPLog(@"command: nothing to group");
            DPRunOps(delegate, browser, ops, 0);
        });
    });
}

@implementation DPGroupCommand
+ (instancetype)shared {
    static DPGroupCommand *command;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ command = [DPGroupCommand new]; });
    return command;
}
- (void)groupTabsByDomain:(id)sender { DPGroupTabsOnce(); }
@end

static NSMenuItem *DPGroupMenuItem(void) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:DPGroupMenuTitle action:@selector(groupTabsByDomain:) keyEquivalent:@""];
    item.target = DPGroupCommand.shared;
    item.tag = DPGroupMenuTag;
    return item;
}

static void DPPlaceGroupItem(NSMenu *menu) {
    if (DPInserting || !menu) return;
    NSInteger anchor = NSNotFound, existing = NSNotFound;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if (item.tag == DPGroupMenuTag) existing = i;
        else if (DPIsNewGroupTitle(item.title)) anchor = i;
    }
    if (anchor == NSNotFound) return;
    NSInteger want = anchor + 1;
    if (existing == want) return;
    DPInserting = YES;
    NSMenuItem *item = existing != NSNotFound ? [menu itemAtIndex:existing] : DPGroupMenuItem();
    if (existing != NSNotFound) {
        [menu removeItemAtIndex:existing];
        if (existing < want) want--;
    }
    if (want > (NSInteger)menu.numberOfItems) want = menu.numberOfItems;
    [menu insertItem:item atIndex:want];
    DPInserting = NO;
    DPLog([NSString stringWithFormat:@"context menu: placed at %ld in \"%@\"", (long)want, menu.title.length ? menu.title : @"(untitled)"]);
}

static void DPInstallMenuBarItem(void) {
    NSMenu *bar = NSApp.mainMenu;
    if (!bar) { DPLog(@"menu bar: main menu missing"); return; }
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSMenu *tabMenu = nil, *commandMenu = nil, *windowMenu = nil, *fileMenu = nil;
    NSString *tabTitle = nil, *commandTitle = nil;
    for (NSMenuItem *top in bar.itemArray) {
        [titles addObject:top.title ?: @""];
        NSString *title = top.title ?: @"";
        if ([title isEqualToString:@"Tab"] || [title isEqualToString:@"Tabs"]) { tabMenu = top.submenu; tabTitle = title; }
        if ([title isEqualToString:@"Window"]) windowMenu = top.submenu;
        if ([title isEqualToString:@"File"]) fileMenu = top.submenu;
        for (NSMenuItem *item in top.submenu.itemArray) {
            if (DPIsNewGroupTitle(item.title) || [item.title isEqualToString:@"New Tab"] || [item.title isEqualToString:@"Close Tab"]
                || [item.title isEqualToString:@"Select Next Tab"] || [item.title isEqualToString:@"Reopen Closed Tab"]) {
                commandMenu = top.submenu;
                commandTitle = title;
            }
        }
    }
    NSMenu *menu = tabMenu ?: commandMenu ?: windowMenu ?: fileMenu;
    NSString *chosen = tabMenu ? tabTitle : commandMenu ? commandTitle : windowMenu ? @"Window" : fileMenu ? @"File" : nil;
    DPLog([NSString stringWithFormat:@"menu bar titles: %@", [titles componentsJoinedByString:@", "]]);
    if (!menu) { DPLog(@"menu bar: no suitable menu"); return; }
    if ([menu itemWithTag:DPGroupMenuTag]) { DPLog([NSString stringWithFormat:@"menu bar: already in %@", chosen]); return; }
    NSInteger index = menu.numberOfItems;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSString *title = [menu itemAtIndex:i].title;
        if (DPIsNewGroupTitle(title) || [title isEqualToString:@"New Tab"]) index = i + 1;
    }
    DPInserting = YES;
    [menu insertItem:DPGroupMenuItem() atIndex:MIN(index, menu.numberOfItems)];
    DPInserting = NO;
    DPLog([NSString stringWithFormat:@"menu bar: inserted in %@ at %ld", chosen, (long)MIN(index, (NSInteger)menu.numberOfItems - 1)]);
}

static void DPMenu_addItem(NSMenu *self, SEL _cmd, NSMenuItem *item) {
    DPCallOriginal(void (*)(id, SEL, id), self, _cmd, item);
    if (!DPInserting && DPIsNewGroupTitle(item.title)) DPPlaceGroupItem(self);
}

static void DPMenu_insertItem(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    DPCallOriginal(void (*)(id, SEL, id, NSInteger), self, _cmd, item, index);
    if (!DPInserting && DPIsNewGroupTitle(item.title)) DPPlaceGroupItem(self);
}

static void DPSetTweak(DPTweak tweak, BOOL on) {
    if (DPOn[tweak] == on) return;
    DPOn[tweak] = on;
    [DPDefaults setBool:on forKey:DPKeys[tweak]];
    if (tweak < DPAnimatedCount) DPAnimate();
    else {
        if (on) for (NSView *bar in DPBars) DPEnforceButtons(bar);
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

@interface DPPaneView : NSView
@property (nonatomic, strong) NSArray<NSSwitch *> *toggles;
@property (nonatomic, strong) NSTextField *status;
@property (nonatomic, strong) NSButton *checkButton;
@property (nonatomic, strong) NSButton *relaunchButton;
@end

@implementation DPPaneView

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    static const struct { DPTweak tweak; __unsafe_unretained NSString *symbol, *title, *detail; } rows[] = {
        {DPEdgeToEdge, @"squareshape.squareshape.dotted", @"Edge-to-edge web content", @"Remove the padding between web pages and the window edge."},
        {DPSquareSidebarCorners, @"square", @"Square corners by the sidebar", @"Let web pages meet the sidebar with straight edges."},
        {DPHideToolbar, @"menubar.rectangle", @"Hide toolbar", @"Remove the bar with the address, navigation buttons and extensions. Experimental."},
        {DPHideSidebarButton, @"sidebar.left", @"Hide sidebar button", @"Hide the sidebar toggle at the top left of the toolbar."},
        {DPHideChatButton, @"bubble.fill", @"Hide Chat button", @"Hide the Chat button at the top right of the toolbar."},
    };
    NSArray<NSColor *> *tints = @[NSColor.systemBlueColor, NSColor.systemIndigoColor, NSColor.systemGrayColor, NSColor.systemOrangeColor, NSColor.systemPurpleColor];
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
        [tweakRows addObject:DPRow(leading, toggle)];
    }
    _toggles = toggles;
    [self updateToggles];

    _status = DPLabel(@"", 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
    _checkButton = [NSButton buttonWithTitle:@"Check for Updates" target:self action:@selector(checkForUpdates:)];
    _relaunchButton = [NSButton buttonWithTitle:@"Relaunch to Update" target:self action:@selector(relaunchToUpdate:)];
    _relaunchButton.bezelColor = NSColor.controlAccentColor;
    _relaunchButton.hidden = YES;
    NSStackView *buttons = [NSStackView stackViewWithViews:@[_relaunchButton, _checkButton]];
    NSButton *restore = [NSButton buttonWithTitle:@"Restore…" target:self action:@selector(restore:)];

    NSStackView *content = [NSStackView stackViewWithViews:@[
        DPLabel(@"Interface", 12, NSFontWeightSemibold, NSColor.secondaryLabelColor),
        DPGroup(tweakRows),
        DPLabel(@"Updates", 12, NSFontWeightSemibold, NSColor.secondaryLabelColor),
        DPGroup(@[
            DPRow(_status, buttons),
            DPRow(DPLabel(@"Restore the original Dia without patches.", 13, NSFontWeightRegular, NSColor.labelColor), restore),
        ]),
        DPLabel(@"DiaPatches is unofficial and not affiliated with The Browser Company.", 11, NSFontWeightRegular, NSColor.tertiaryLabelColor),
    ]];
    content.orientation = NSUserInterfaceLayoutOrientationVertical;
    content.alignment = NSLayoutAttributeLeading;
    content.spacing = 8;
    for (NSView *v in content.arrangedSubviews) [v.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:content];
    NSLayoutConstraint *fill = [content.widthAnchor constraintEqualToAnchor:self.widthAnchor constant:-48];
    fill.priority = NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:self.topAnchor constant:72],
        [content.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [content.widthAnchor constraintLessThanOrEqualToConstant:560],
        fill,
    ]];
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

- (void)updateToggles {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.allowsImplicitAnimation = YES;
        for (NSSwitch *toggle in self.toggles) {
            if (toggle.tag == DPHideSidebarButton || toggle.tag == DPHideChatButton) toggle.enabled = !DPOn[DPHideToolbar];
            if (toggle.tag != DPSquareSidebarCorners) continue;
            NSView *row = toggle.superview;
            NSArray *siblings = row.superview.subviews;
            NSView *separator = siblings[[siblings indexOfObject:row] - 1];
            row.hidden = separator.hidden = !DPOn[DPEdgeToEdge];
        }
        [self layoutSubtreeIfNeeded];
    }];
}

- (void)toggle:(NSSwitch *)sender {
    DPSetTweak(sender.tag, sender.state == NSControlStateValueOn);
    [self updateToggles];
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
@property (nonatomic) BOOL hovered;
@property (nonatomic, strong) NSImageView *icon;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic) NSRect iconFrame, labelFrame, pillFrame;
@property (nonatomic, strong) NSFont *labelFont;
@property (nonatomic) CGFloat pillRadius;
@end

@implementation DPSidebarRow {
    NSTrackingArea *_tracking;
    NSView *_hover;
    NSVisualEffectView *_selection;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _hover = [NSView new];
    _hover.wantsLayer = YES;
    _selection = [NSVisualEffectView new];
    _selection.material = NSVisualEffectMaterialSelection;
    _selection.state = NSVisualEffectStateFollowsWindowActiveState;
    _selection.wantsLayer = YES;
    _selection.hidden = YES;
    _icon = [DPSolidImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"wand.and.stars" accessibilityDescription:nil]];
    _label = [DPSolidLabel labelWithString:@"Patches"];
    for (NSView *v in @[_hover, _selection, _icon, _label]) [self addSubview:v];
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

- (void)layout {
    [super layout];
    for (NSView *v in @[_hover, _selection]) {
        v.frame = self.pillFrame;
        v.layer.cornerRadius = self.pillRadius;
        v.layer.masksToBounds = YES;
    }
    self.icon.frame = self.iconFrame;
    [self.label sizeToFit];
    NSRect labelFrame = self.labelFrame;
    labelFrame.size.width = MAX(labelFrame.size.width, NSWidth(self.label.frame));
    self.label.frame = labelFrame;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_tracking) [self removeTrackingArea:_tracking];
    _tracking = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:nil];
    [self addTrackingArea:_tracking];
}

- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; }
- (void)setHovered:(BOOL)hovered { _hovered = hovered; [self redraw]; }
- (void)setSelected:(BOOL)selected { _selected = selected; [self redraw]; }

- (void)updateLayer {
    BOOL key = self.window.isKeyWindow, emphasized = self.selected && key;
    _selection.hidden = !self.selected;
    _selection.emphasized = emphasized;
    _hover.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:self.hovered && !self.selected ? 0.05 : 0].CGColor;
    self.label.textColor = emphasized ? NSColor.alternateSelectedControlTextColor : key || self.selected ? NSColor.labelColor : NSColor.secondaryLabelColor;
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
        NSPoint inDetail = [me.detail convertPoint:event.locationInWindow fromView:nil];
        if (NSPointInRect(inDetail, me.detail.bounds)) return nil;
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
    if ([self.title.stringValue isEqualToString:@"Patches"]) self.title.stringValue = self.originalTitle;
    if (self.table.selectedRow == self.deselectedIndex) [self.table rowViewAtRow:self.deselectedIndex makeIfNecessary:NO].selected = YES;
    self.row.selected = NO;
}
@end

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
    DPTrackedContents = [NSHashTable weakObjectsHashTable];
    DPBrowsers = [NSHashTable weakObjectsHashTable];
    DPBrowserByContents = [NSMapTable weakToWeakObjectsMapTable];
    DPDelegateByBrowser = [NSMapTable weakToWeakObjectsMapTable];
    DPWindowByBrowser = [NSMapTable weakToWeakObjectsMapTable];

    DPHook(DPContainerClass(), @selector(setFrame:), (IMP)DPContainer_setFrame);
    for (NSString *selector in @[@"layout", @"updateLayer"])
        DPHook(DPContainerClass(), NSSelectorFromString(selector), (IMP)DPContainer_layoutOrUpdateLayer);
    DPHook(NSClassFromString(@"_TtC5ARCUI10ShadowView"), @selector(layout), (IMP)DPShadow_layout);
    DPHook(NSClassFromString(@"_TtC11ContentPane15ContentPaneView"), @selector(layout), (IMP)DPPane_layout);
    DPHook(DPToolbarClass(), @selector(layout), (IMP)DPBar_layout);
    DPHook(DPToolbarClass(), @selector(hitTest:), (IMP)DPToolbar_hitTest);
    DPHook(NSClassFromString(DPSettingsControllerClass), @selector(viewDidAppear), (IMP)DPSettings_viewDidAppear);
    DPHook(NSClassFromString(@"ArcBrowser"), @selector(setDelegate:), (IMP)DPBrowser_setDelegate);
    DPHook(NSClassFromString(@"ArcBrowser"), @selector(setWindow:), (IMP)DPBrowser_setWindow);
    Class browserDelegate = NSClassFromString(@"_TtC3ADK15ChromiumBrowser");
    DPHook(browserDelegate, @selector(browser:didRestoreWebContents:withSessionId:), (IMP)DPBrowser_didRestore);
    DPHook(browserDelegate, @selector(browser:didCreateNewWebContents:isActive:), (IMP)DPBrowser_didCreate);
    DPHook(NSMenu.class, @selector(addItem:), (IMP)DPMenu_addItem);
    DPHook(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPMenu_insertItem);

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *_) {
        DPInstallUpdateMenuItem();
        DPRunCLI(@[@"update"], nil);
        DPInstallMenuBarItem();
    }];
    [center addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *_) {
        DPApplyStagedOnQuit();
    }];
    if (!DPHookNotes) DPHookNotes = [NSMutableArray array];
    [DPHookNotes addObject:@"loaded"];
    DPLog(@"loaded");
}
