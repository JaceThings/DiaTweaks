#import "Patches/CommandBar/HideTab.h"

static char DPBeforeKey, DPHiddenKey, DPDiaFrameKey;
static NSHashTable<NSView *> *DPHeldStrips;
static void (*DPSetFrame)(NSView *, SEL, NSRect);

NSString *DPStripTabID(NSView *tabView) {
    NSView *content = DPFindView(tabView, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTabContentView); });
    NSString *tab = [DPSwiftValue(DPSwiftValue(DPSwiftValue(content, @"viewModel"), @"delegate"), @"tabID") description];
    return tab ? DPUUIDsIn(tab).firstObject : nil;
}

static NSRect DPDiaFrame(NSView *view) {
    NSValue *dia = DPGet(view, &DPDiaFrameKey);
    return dia ? dia.rectValue : view.frame;
}

// Dia slides what it moves, so a view kept in place loses its slide, or it would slide away and back.
static void DPStopSliding(NSView *view) {
    for (NSString *key in view.layer.animationKeys) {
        CAAnimation *animation = [view.layer animationForKey:key];
        NSString *path = [animation isKindOfClass:CAPropertyAnimation.class] ? ((CAPropertyAnimation *)animation).keyPath : nil;
        if ([path hasPrefix:@"position"] || [path hasPrefix:@"bounds"] || [path hasPrefix:@"frame"]) [view.layer removeAnimationForKey:key];
    }
}

static void DPPlace(NSView *view, NSRect frame) {
    if (!NSEqualRects(view.frame, frame))
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0;
            context.allowsImplicitAnimation = NO;
            [CATransaction setDisableActions:YES];
            DPSetFrame(view, @selector(setFrame:), frame);
        }];
}

static void DPView_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSView *strip = DPHeldStrips.count ? self.superview : nil;
    if (!strip || ![DPHeldStrips containsObject:strip]) return DPSetFrame(self, _cmd, frame);
    NSValue *before = [DPGet(strip, &DPBeforeKey) objectForKey:self];
    DPSet(self, &DPDiaFrameKey, [NSValue valueWithRect:frame]);
    DPSetFrame(self, _cmd, before ? before.rectValue : frame);
    if (before) DPStopSliding(self);
}

void DPHoldStrips(NSWindow *window) {
    for (NSView *strip in DPFindViews(DPDiaTabStripTabs)) {
        if (strip.window != window || [DPHeldStrips containsObject:strip]) continue;
        NSMapTable<NSView *, NSValue *> *before = [NSMapTable weakToStrongObjectsMapTable];
        for (NSView *view in strip.subviews) [before setObject:[NSValue valueWithRect:view.frame] forKey:view];
        DPSet(strip, &DPBeforeKey, before);
        DPSet(strip, &DPHiddenKey, [NSHashTable weakObjectsHashTable]);
        [DPHeldStrips addObject:strip];
    }
}

static void DPRelease(NSView *strip) {
    [DPHeldStrips removeObject:strip];
    for (NSView *view in [DPGet(strip, &DPHiddenKey) allObjects]) view.hidden = NO;
    for (NSView *view in strip.subviews) {
        DPPlace(view, DPDiaFrame(view));
        DPSet(view, &DPDiaFrameKey, nil);
    }
    DPSet(strip, &DPBeforeKey, nil);
    DPSet(strip, &DPHiddenKey, nil);
}

// A strip that isn't held, such as one made as the tab layout changes, just leaves the hidden tab out.
static void DPLeaveOut(NSView *strip) {
    NSHashTable<NSView *> *hidden = DPGet(strip, &DPHiddenKey);
    if (!DPHidingATab() && !DPParkingAny() && !hidden.count) return;
    for (NSView *view in strip.subviews) {
        NSString *tab = DPIsKind(view, DPDiaTabView) ? DPStripTabID(view) : nil;
        BOOL out = tab && DPHidesTab(tab);
        if (out && !view.hidden) {
            if (!hidden) DPSet(strip, &DPHiddenKey, hidden = [NSHashTable weakObjectsHashTable]);
            view.hidden = YES;
            [hidden addObject:view];
        } else if (!out && [hidden containsObject:view]) {
            view.hidden = NO;
            [hidden removeObject:view];
        }
    }
}

static void DPHold(NSView *strip) {
    NSMapTable<NSView *, NSValue *> *before = DPGet(strip, &DPBeforeKey);
    if (!before) return DPLeaveOut(strip);
    if (!DPHidingATab()) return DPRelease(strip);
    NSHashTable<NSView *> *hidden = DPGet(strip, &DPHiddenKey);
    for (NSView *view in strip.subviews) {
        NSValue *frame = [before objectForKey:view];
        NSString *tab = DPIsKind(view, DPDiaTabView) ? DPStripTabID(view) : nil;
        // A tab the bar isn't hiding that wasn't there before, such as one another app opened, lets the strip go.
        if (!frame && tab && !DPHidesTab(tab)) return DPRelease(strip);
        if (frame && !(tab && DPHidesTab(tab))) {
            DPPlace(view, frame.rectValue);
            DPStopSliding(view);
        } else if (!view.hidden) {
            view.hidden = YES;
            [hidden addObject:view];
        }
    }
}

static void DPStrip_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPStrip_layout, self);
    DPHold(self);
}

void DPInstallHiddenStripTab(void) {
    DPHook(DPDiaTabStripTabs, @selector(layout), (IMP)DPStrip_layout);
    DPHeldStrips = [NSHashTable weakObjectsHashTable];
    // Every view's, so it's swapped in directly rather than through DPHook, and only looks further while a strip is held.
    Method setFrame = class_getInstanceMethod(NSView.class, @selector(setFrame:));
    DPSetFrame = (void *)method_setImplementation(setFrame, (IMP)DPView_setFrame);
    // Before Core Animation commits what's drawn this turn.
    CFRunLoopObserverRef beforeDraw = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, YES, 0, ^(CFRunLoopObserverRef o, CFRunLoopActivity a) {
        for (NSView *strip in DPHeldStrips.allObjects) DPHold(strip);
    });
    CFRunLoopAddObserver(CFRunLoopGetMain(), beforeDraw, kCFRunLoopCommonModes);
    CFRelease(beforeDraw);
}
