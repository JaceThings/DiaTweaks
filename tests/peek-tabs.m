#import "Patches/Peek/Peek.h"

static NSString *front;
static NSArray *cards;
static int failures;
NSString *DPActiveTabID(NSWindow *window) { return front; }
id DPSwiftValue(id object, NSString *key) { return nil; }
BOOL DPIsKind(id object, const char *name) { return NO; }
NSArray *DPFindViews(const char *name) { return strcmp(name, "DPPeekCard") == 0 ? cards : @[]; }

@implementation DPPeekCard
- (NSRect)cardFrame { return self.bounds; }
- (void)close:(DPPeekExit)exit { self.closing = YES; [self removeFromSuperview]; }
- (void)handOver { [self removeFromSuperview]; }
@end

#import "Patches/Peek/Tab.m"

static void Check(BOOL ok, const char *message) {
    if (!ok) { fprintf(stderr, "FAIL %s\n", message); failures++; }
}

static DPPeekCard *Card(NSWindow *window, id source, NSString *tabID) {
    DPPeekCard *peek = [DPPeekCard new];
    peek.source = source;
    [window.contentView addSubview:peek];
    DPPeekTabBadge *badge = [DPPeekTabBadge new];
    badge.peek = peek;
    badge.frontIDAtOpen = tabID;
    peek.tabBadge = badge;
    return peek;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed = NO;
        NSObject *sourceA = [NSObject new], *sourceB = [NSObject new];
        DPPeekCard *a = Card(window, sourceA, @"A"), *b = Card(window, sourceB, @"B");
        cards = @[a, b];
        front = @"A";
        DPPeekSyncTabs(window);
        Check(!a.hidden && b.hidden && !a.closing && !b.closing, "only A's Peek is visible");
        front = @"B";
        DPPeekSyncTabs(window);
        Check(a.hidden && !b.hidden, "switching preserves A and shows B");
        front = @"C";
        DPPeekSyncTabs(window);
        Check(a.hidden && b.hidden, "another tab has no Peek");
        front = @"A";
        DPPeekSyncTabs(window);
        Check(!a.hidden && b.hidden && a.source == sourceA, "returning restores the same card and source");
        front = nil;
        DPPeekSyncTabs(window);
        Check(a.hidden && b.hidden, "unreadable selection does not expose another tab's card");
        a.source = nil;
        DPPeekSyncTabs(window);
        Check(a.closing && !a.superview && !b.closing, "source destruction closes only its own Peek");
        cards = @[];
        [window close];
        printf("peek-tabs: %d failures\n", failures);
    }
    return failures ? 1 : 0;
}
