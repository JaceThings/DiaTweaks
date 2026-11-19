#import "Patches/Peek/Peek.h"
#import "Patches/CommandBar/Tabs.h"

static char DPPeekCardsKey, DPPeekSelectedTabKey, DPPeekLivenessKey;

static void DPPeekUpdateLiveness(NSWindow *window);

NSArray<DPPeekCard *> *DPPeekCardsIn(NSWindow *window) { return DPGet(window, &DPPeekCardsKey); }

void DPPeekTrackCard(DPPeekCard *peek) {
    NSWindow *window = peek.originWindow;
    NSMutableArray *cards = DPGet(window, &DPPeekCardsKey);
    if (!cards) DPSet(window, &DPPeekCardsKey, cards = [NSMutableArray new]);
    [cards addObject:peek];
}

void DPPeekForgetCard(DPPeekCard *peek) {
    NSWindow *window = peek.originWindow;
    if (!window) return;
    NSMutableArray *cards = DPGet(window, &DPPeekCardsKey);
    [cards removeObjectIdenticalTo:peek];
    if (!cards.count) {
        DPSet(window, &DPPeekCardsKey, nil);
        DPSet(window, &DPPeekSelectedTabKey, nil);
    }
    DPPeekUpdateLiveness(window);
}

static void DPPeekPruneClosedOrigins(NSWindow *window, id scriptWindow, NSString *active) {
    if (!active) return;
    // A sidebar row can disappear when virtualized. Only the actual tab list can tell us it closed.
    NSArray *tabs = [scriptWindow valueForKey:@"appleScriptTabs"];
    if (!tabs.count) return;
    NSMutableSet<NSString *> *openIDs = [NSMutableSet set];
    for (id tab in tabs) {
        NSString *tabID = DPTabID(tab);
        if (tabID) [openIDs addObject:tabID];
    }
    if (![openIDs containsObject:active]) return;
    for (DPPeekCard *peek in [DPPeekCardsIn(window) copy])
        if (peek.hidden && !peek.closing && peek.originTabID && ![openIDs containsObject:peek.originTabID]) [peek close:DPPeekClose];
}

static void DPPeekUpdateLiveness(NSWindow *window) {
    BOOL parked = NO;
    for (DPPeekCard *peek in DPPeekCardsIn(window))
        if (peek.hidden && !peek.closing && peek.originTabID) { parked = YES; break; }
    NSTimer *timer = DPGet(window, &DPPeekLivenessKey);
    if (!parked) {
        [timer invalidate];
        DPSet(window, &DPPeekLivenessKey, nil);
    } else if (!timer) {
        // Closing a background tab doesn't select anything. Check only when a live Peek is parked.
        __weak NSWindow *weak = window;
        timer = [NSTimer timerWithTimeInterval:0.6 repeats:YES block:^(NSTimer *timer) {
            NSWindow *window = weak;
            if (!window) return [timer invalidate];
            id scriptWindow = DPScriptWindow(window);
            DPPeekPruneClosedOrigins(window, scriptWindow, DPActiveTabIDIn(scriptWindow));
        }];
        DPSet(window, &DPPeekLivenessKey, timer);
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    }
}

void DPPeekSelectionChanged(NSWindow *window, id scriptWindow, NSString *active) {
    if (!active) return;
    DPPeekHandoffSelectionChanged(window, active);
    NSArray<DPPeekCard *> *cards = [DPPeekCardsIn(window) copy];
    if (!cards.count) return;
    for (DPPeekCard *peek in cards)
        if (peek.originTabID) [peek setOriginVisible:[active isEqual:peek.originTabID]];

    DPPeekUpdateLiveness(window);
    if ([DPGet(window, &DPPeekSelectedTabKey) isEqual:active]) return;
    DPSet(window, &DPPeekSelectedTabKey, active);
    DPPeekPruneClosedOrigins(window, scriptWindow, active);
}
