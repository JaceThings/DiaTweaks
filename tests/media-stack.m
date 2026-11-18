// Media Controls' stack model: which background tabs get a card, in what order.
// clang -fobjc-arc -Isrc/dylib -framework AppKit tests/media-stack.m -o build/media-stack && build/media-stack
#import "Patches/MediaControls/Model.m"

#define CHECK(cond) do { if (!(cond)) { printf("FAIL %s: %s\n", __func__, #cond); exit(1); } } while (0)

static DPMediaItem *item(id tab, BOOL playing) {
    DPMediaItem *item = [DPMediaItem new];
    item.tab = tab;
    item.playing = playing;
    return item;
}

static NSArray *tabsOf(DPMediaStack *stack) { return [stack.visible valueForKey:@"tab"]; }

static id A, B, C, other;

static void selectedHidden(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES) ] selectedTab:A];
    CHECK(s.visible.count == 0 && s.count == 0);
    [s updateWithItems:@[ item(A, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:@[ A ]]);
}

static void recentFirst(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:(@[ B, A ])]);
    CHECK(s.count == 2);
}

static void maxTwo(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(A, YES), item(B, YES), item(C, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:(@[ C, B ])]);
    CHECK(s.count == 3);
}

static void pausedStays(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES), item(B, NO) ] selectedTab:other];
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(A, NO), item(B, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:(@[ B, A ])]);
}

static void closed(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(B, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:@[ B ]]);
}

static void ended(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES) ] selectedTab:other];
    [s updateWithItems:@[] selectedTab:other];
    CHECK(s.visible.count == 0 && s.count == 0);
}

static void dismissed(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    [s dismiss:A];
    CHECK([tabsOf(s) isEqual:@[ B ]]);
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:@[ B ]]);
    [s updateWithItems:@[ item(A, NO), item(B, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:@[ B ]]);
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:(@[ A, B ])]);
}

static void window(void) {
    DPMediaStack *one = [DPMediaStack new], *two = [DPMediaStack new];
    [one updateWithItems:@[ item(A, YES) ] selectedTab:other];
    [one updateWithItems:@[] selectedTab:other];
    [two updateWithItems:@[ item(A, YES) ] selectedTab:other];
    CHECK(one.visible.count == 0);
    CHECK([tabsOf(two) isEqual:@[ A ]]);
}

static void restartMovesFront(void) {
    DPMediaStack *s = [DPMediaStack new];
    [s updateWithItems:@[ item(A, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(A, NO), item(B, YES) ] selectedTab:other];
    [s updateWithItems:@[ item(A, YES), item(B, YES) ] selectedTab:other];
    CHECK([tabsOf(s) isEqual:(@[ A, B ])]);
}

int main(void) {
    @autoreleasepool {
        A = [NSObject new], B = [NSObject new], C = [NSObject new], other = [NSObject new];
        void (*cases[])(void) = { selectedHidden, recentFirst, maxTwo, pausedStays, closed, ended, dismissed, window, restartMovesFront };
        for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) cases[i]();
        printf("ok %zu cases\n", sizeof cases / sizeof *cases);
    }
    return 0;
}
