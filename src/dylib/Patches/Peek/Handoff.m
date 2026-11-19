#import "Patches/Peek/Peek.h"
#import <dlfcn.h>

static char DPPeekCoverKey;
typedef CGImageRef (*DPPeekWindowCapture)(CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption);

static DPPeekWindowCapture DPPeekCaptureOwnWindow(void) {
    static DPPeekWindowCapture capture;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The SDK obsoletes this API, but the runtime can still capture a window owned by this app without screen recording access.
        capture = dlsym(RTLD_DEFAULT, "CGWindowListCreateImage");
    });
    return capture;
}

@interface DPPeekCover : NSWindow
@property (nonatomic, weak) NSView *destination;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, copy) void (^promote)(void);
@property (nonatomic) NSUInteger visibleFrames;
@property (nonatomic) BOOL presented;
- (void)dismiss;
@end

@implementation DPPeekCover
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }

- (void)dismiss {
    void (^promote)(void) = self.promote;
    self.promote = nil;
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self orderOut:nil];
    [self.parentWindow removeChildWindow:self];
    if (promote) promote();
}

- (void)step:(CADisplayLink *)link {
    if (self.promote) {
        // Commit a frame with the child window before native tab selection starts.
        if (!self.presented) {
            self.presented = YES;
            return;
        }
        void (^promote)(void) = self.promote;
        self.promote = nil;
        promote();
        return;
    }
    NSView *destination = self.destination;
    NSWindow *parent = self.parentWindow;
    if (!parent.isVisible) return [self dismiss];
    BOOL visible = destination.window == parent && !destination.isHiddenOrHasHiddenAncestor && !NSIsEmptyRect(destination.visibleRect);
    self.visibleFrames = visible ? self.visibleFrames + 1 : 0;
    // Give Chromium's remote compositor two presentations before uncovering the new tab.
    if (self.visibleFrames >= 3) [self dismiss];
}
@end

void DPPeekCompleteHandoff(DPPeekCard *peek, NSView *destination) {
    DPPeekCover *cover = DPGet(peek, &DPPeekCoverKey);
    DPSet(peek, &DPPeekCoverKey, nil);
    if (cover.parentWindow && destination) cover.destination = destination;
    else [cover dismiss];
}

static void DPPeekShowCover(DPPeekCard *peek, CGImageRef contents, void (^promote)(void)) {
    NSWindow *parent = peek.window;
    if (!parent.isVisible || !contents) return promote();
    NSRect frame = [parent convertRectToScreen:[peek convertRect:peek.bounds toView:nil]];
    DPPeekCover *cover = [[DPPeekCover alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless
                                                          backing:NSBackingStoreBuffered defer:NO];
    cover.opaque = NO;
    cover.backgroundColor = NSColor.clearColor;
    cover.hasShadow = NO;
    cover.ignoresMouseEvents = YES;
    cover.excludedFromWindowsMenu = YES;
    cover.restorable = NO;
    cover.releasedWhenClosed = NO;
    cover.animationBehavior = NSWindowAnimationBehaviorNone;
    cover.collectionBehavior = NSWindowCollectionBehaviorIgnoresCycle | NSWindowCollectionBehaviorFullScreenAuxiliary;
    NSView *content = [[NSView alloc] initWithFrame:(NSRect){NSZeroPoint, frame.size}];
    CALayer *layer = [CALayer layer];
    layer.frame = content.bounds;
    layer.contentsScale = parent.backingScaleFactor;
    layer.contents = (__bridge id)contents;
    content.layer = layer;
    content.wantsLayer = YES;
    cover.contentView = content;
    cover.promote = promote;
    DPSet(peek, &DPPeekCoverKey, cover);
    [parent addChildWindow:cover ordered:NSWindowAbove];
    cover.displayLink = [parent displayLinkWithTarget:cover selector:@selector(step:)];
    [cover.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    // A hidden or switched-away destination may never get its display ticks.
    __weak DPPeekCover *weak = cover;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        DPPeekCover *cover = weak;
        if (cover.displayLink) [cover dismiss];
    });
}

void DPPeekPrepareHandoff(DPPeekCard *peek, void (^complete)(void)) {
    NSWindow *window = peek.window;
    NSScreen *primary = NSScreen.screens.firstObject;
    DPPeekWindowCapture capture = DPPeekCaptureOwnWindow();
    if (!capture || !primary || !window.isVisible || window.windowNumber <= 0 || window.sharingType == NSWindowSharingNone) return complete();
    NSRect frame = [window convertRectToScreen:[peek convertRect:peek.bounds toView:nil]];
    if (NSIsEmptyRect(frame)) return complete();
    CGRect screenBounds = CGRectMake(NSMinX(frame), NSMaxY(primary.frame) - NSMaxY(frame), NSWidth(frame), NSHeight(frame));
    CGWindowID windowID = (CGWindowID)window.windowNumber;
    [CATransaction flush];  // Include the expanded Peek in the WindowServer image.
    __block BOOL done = NO;
    void (^finish)(CGImageRef) = ^(CGImageRef image) {
        if (done) return;
        done = YES;
        if (peek.window == window) DPPeekShowCover(peek, image, complete);
        else complete();
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 70 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ finish(NULL); });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        CGImageRef image = capture(screenBounds, kCGWindowListOptionIncludingWindow, windowID, kCGWindowImageBestResolution);
        dispatch_async(dispatch_get_main_queue(), ^{
            finish(image);
            if (image) CGImageRelease(image);
        });
    });
}
