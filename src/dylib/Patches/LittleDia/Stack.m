#import "LittleDia.h"

// A link from another app makes macOS bring Dia forward, and Dia's main window with it. Little Dia puts the main window
// back where it was: the order of the windows on screen is noted just before Dia comes forward, and after the small
// window opens, every Dia window that was behind the app the link came from goes back behind it.

static NSArray<NSDictionary *> *DPBeforeActivating, *DPForLink;
static NSDate *DPNotedAt;
static pid_t DPSource;  // The app the link was clicked in, if Dia wasn't in front.

// Normal windows on screen, front to back, with the app each belongs to. Needs no screen recording permission.
static NSArray<NSDictionary *> *DPWindowStack(void) {
    NSArray *list = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    NSMutableArray *stack = [NSMutableArray array];
    for (NSDictionary *info in list)
        if ([info[(id)kCGWindowLayer] integerValue] == 0) [stack addObject:@{@"number" : info[(id)kCGWindowNumber], @"pid" : info[(id)kCGWindowOwnerPID]}];
    return stack;
}

void DPNoteStackForLink(void) {
    if (!NSApp.active) DPForLink = DPWindowStack();
    else if (DPNotedAt && DPNotedAt.timeIntervalSinceNow > -2) DPForLink = DPBeforeActivating;
    else DPForLink = nil;  // Dia was already in front: nothing to put back.
    NSNumber *me = @(getpid());
    DPSource = 0;
    for (NSDictionary *window in DPForLink)
        if (![window[@"pid"] isEqual:me]) {
            DPSource = [window[@"pid"] intValue];
            break;
        }
}

pid_t DPLinkSource(void) { return DPSource; }

// Closing the window goes back to that app, instead of Dia bringing its main window up in its place.
void DPReturnToSource(pid_t pid) {
    NSRunningApplication *app = pid ? [NSRunningApplication runningApplicationWithProcessIdentifier:pid] : nil;
    if (!app || app.terminated) return;
    if (@available(macOS 14, *)) [app activateFromApplication:NSRunningApplication.currentApplication options:0];
    else [app activateWithOptions:0];
}

void DPRestoreStack(NSWindow *little) {
    NSArray<NSDictionary *> *stack = DPForLink;
    NSNumber *me = @(getpid());
    NSUInteger front = [stack indexOfObjectPassingTest:^BOOL(NSDictionary *window, NSUInteger i, BOOL *stop) { return ![window[@"pid"] isEqual:me]; }];
    if (front == NSNotFound) return;
    NSInteger anchor = [stack[front][@"number"] integerValue];
    // Back to front, so each lands just behind that window and they keep their order.
    NSMutableArray<NSWindow *> *behind = [NSMutableArray array];
    for (NSWindow *window in NSApp.orderedWindows) {
        if (window == little || !window.visible || window.level != NSNormalWindowLevel) continue;
        NSUInteger at = [stack indexOfObjectPassingTest:^BOOL(NSDictionary *each, NSUInteger i, BOOL *stop) { return [each[@"number"] integerValue] == window.windowNumber; }];
        if (at != NSNotFound && at > front) [behind insertObject:window atIndex:0];
    }
    for (NSWindow *window in behind) [window orderWindow:NSWindowBelow relativeTo:anchor];
}

void DPFinishStack(void) { DPForLink = nil; }

void DPInstallLittleDiaStack(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillBecomeActiveNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) {
                                                    DPBeforeActivating = DPWindowStack();
                                                    DPNotedAt = [NSDate date];
                                                }];
}
