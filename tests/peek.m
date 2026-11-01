#import "Patches/Peek/Controller.h"

@interface PeekContentsFixture : NSObject
@property(nonatomic, strong) NSView *nativeView;
@property(nonatomic, strong) NSURL *loadedURL;
@property(nonatomic) NSUInteger stops, detaches;
@property(nonatomic) BOOL failLoad;
@end
@implementation PeekContentsFixture
- (NSView *)createPaneHostView { return [NSView new]; }
- (void)attachToPaneHostView:(NSView *)view {}
- (void)detachFromPaneHostView:(NSView *)view { self.detaches++; }
- (id)navigationController { return self; }
- (id)load:(NSURL *)url initiatorOrigin:(NSURL *)origin { self.loadedURL = url; return self.failLoad ? nil : self; }
- (void)stop { self.stops++; }
@end

@interface PeekConfigurationFixture : NSObject
@end
@implementation PeekConfigurationFixture
- (void)setForeground:(BOOL)value {}
- (void)setUntracked:(BOOL)value {}
@end

@interface PeekBrowserFixture : NSObject
@property(nonatomic, strong) PeekContentsFixture *lastContents;
@property(nonatomic) BOOL failLoad;
@end
@implementation PeekBrowserFixture
- (id)createWebContents:(id)configuration {
    self.lastContents = [PeekContentsFixture new];
    self.lastContents.failLoad = self.failLoad;
    return self.lastContents;
}
@end

static PeekBrowserFixture *browser;
static PeekContentsFixture *source;
id DPPeekBrowser(id contents) { return contents == source ? browser : nil; }
void DPPeekInstallTracking(void) {} // Real Chromium ownership callbacks are covered in the live Dia test.

static NSEvent *mouse(NSEventType type, NSEventModifierFlags modifiers) {
    return [NSEvent mouseEventWithType:type location:NSMakePoint(100, 200) modifierFlags:modifiers timestamp:0
        windowNumber:0 context:nil eventNumber:1 clickCount:1 pressure:1];
}
static void drain(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]]; }

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSURL *url = [NSURL URLWithString:@"https://example.test/preview"];
        NSEvent *shift = mouse(NSEventTypeLeftMouseUp, NSEventModifierFlagShift);
        NSCAssert(DPPeekShouldOpen(shift, 0, 5, url), @"Shift-click previews HTTP links");
        NSCAssert(DPPeekShouldOpen(mouse(NSEventTypeLeftMouseDown, NSEventModifierFlagShift), 0, 5, url), @"mouse-down callbacks work too");
        NSCAssert(!DPPeekShouldOpen(mouse(NSEventTypeLeftMouseUp, 0), 0, 5, url), @"normal clicks retain native behavior");
        for (NSNumber *modifier in @[@(NSEventModifierFlagCommand), @(NSEventModifierFlagOption), @(NSEventModifierFlagControl)])
            NSCAssert(!DPPeekShouldOpen(mouse(NSEventTypeLeftMouseUp, NSEventModifierFlagShift | modifier.unsignedLongLongValue), 0, 5, url), @"other modifier shortcuts remain native");
        NSCAssert(!DPPeekShouldOpen(mouse(NSEventTypeRightMouseUp, NSEventModifierFlagShift), 0, 5, url), @"right clicks remain native");
        NSCAssert(!DPPeekShouldOpen(shift, 1, 5, url), @"non-link navigations remain native");
        NSCAssert(!DPPeekShouldOpen(shift, 0, 0, url), @"a rejected native navigation is not revived");
        NSCAssert(!DPPeekShouldOpen(shift, 0, 5, [NSURL URLWithString:@"javascript:alert(1)"]), @"non-HTTP schemes remain native");
        NSCAssert(!DPPeekShouldOpen(nil, 0, 5, url), @"no event means no preview");

        Class paneClass = objc_allocateClassPair(NSView.class, DPDiaContentPane, 0);
        objc_registerClassPair(paneClass);
        Class configuration = objc_allocateClassPair(PeekConfigurationFixture.class, "ArcWebContentsConfiguration", 0);
        objc_registerClassPair(configuration);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 800)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed = NO;
        window.contentView = [[paneClass alloc] initWithFrame:NSMakeRect(0, 0, 1000, 800)];
        [window orderFront:nil];
        NSView *page = [[NSView alloc] initWithFrame:window.contentView.bounds];
        [window.contentView addSubview:page];
        NSTextField *field = [NSTextField textFieldWithString:@"source state survives"];
        [page addSubview:field];
        source = [PeekContentsFixture new]; source.nativeView = page;
        browser = [PeekBrowserFixture new];
        NSUInteger windows = NSApp.windows.count;
        NSRect originalFrame = page.frame;
        NSCAssert(DPPeekOpen(source, url, NSMakePoint(100, 200)), @"preview opens in source pane");
        DPPeekController *preview = DPPeekControllers.anyObject;
        NSCAssert(preview.overlay.window == window && preview.overlay.host.window == window, @"preview uses source NSWindow");
        NSCAssert(NSApp.windows.count == windows, @"no NSPanel or NSWindow created");
        NSCAssert(fabs(preview.overlay.card.frame.size.width - 850) < 0.1, @"default preview width is 85 percent");
        NSCAssert(NSEqualRects(page.frame, originalFrame) && source.loadedURL == nil, @"source is not moved or navigated");
        NSCAssert([browser.lastContents.loadedURL isEqual:url], @"URL is loaded only in preview");
        NSCAssert(NSEqualPoints(preview.overlay.origin, NSMakePoint(100, 200)), @"animation starts at click point");
        if (!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
            NSCAssert([preview.overlay.card.layer animationForKey:@"peekMotion"] != nil, @"opening motion installed");
            NSCAssert([preview.overlay.layer animationForKey:@"peekFade"] != nil, @"opening fade installed");
        }
        drain();
        NSCAssert([preview.overlay.card.layer animationForKey:@"peekMotion"] == nil, @"completed opening motion must not override future layout");
        NSCAssert([preview.overlay.layer animationForKey:@"peekFade"] == nil, @"completed fade does not override opacity");
        [window setContentSize:NSMakeSize(1200, 800)];
        preview.overlay.needsLayout = YES;
        [preview.overlay layoutSubtreeIfNeeded];
        NSCAssert(fabs(preview.overlay.card.frame.size.width - 1020) < 0.1, @"preview remains 85 percent after resizing");
        [preview dismiss]; drain();
        NSCAssert(DPPeekControllers.count == 0 && window.contentView.subviews.count == 1, @"dismissal removes overlay");
        NSCAssert(browser.lastContents.detaches == 1 && browser.lastContents.stops == 1, @"dismissal releases native host exactly once");
        NSCAssert([field.stringValue isEqualToString:@"source state survives"], @"source input survives");
        [preview close];
        NSCAssert(browser.lastContents.detaches == 1, @"close is idempotent");
        NSCAssert(DPPeekOpen(source, url, NSZeroPoint), @"reopening works");
        DPPeekCloseContents(source);
        NSCAssert(DPPeekControllers.count == 0, @"detaching a source closes its Peek");
        NSCAssert(DPPeekOpen(source, url, NSZeroPoint), @"window-close fixture opens");
        DPPeekCloseWindow(window);
        NSCAssert(DPPeekControllers.count == 0, @"closing a source window cleans up");
        NSCAssert(DPPeekOpen(source, url, NSZeroPoint), @"disable fixture opens");
        DPPeekCloseAll();
        NSCAssert(DPPeekControllers.count == 0, @"disabling cleans up");
        browser.failLoad = YES;
        NSCAssert(!DPPeekOpen(source, url, NSZeroPoint) && DPPeekControllers.count == 0, @"failed native load cleans up without overlay");
        NSCAssert(!DPPeekOpen([PeekContentsFixture new], url, NSZeroPoint), @"unknown owner falls back instead of using another profile");
        [window close];
        puts("PASS: link shortcuts, same-window embedding, 85% width, animation origin, resize, teardown and source state");
    }
}
